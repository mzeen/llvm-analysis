module Data.LLVM.Private.PlaceholderBuilders ( mkExtractElementInst
                                             , mkInsertElementInst
                                             , mkDataLayout
                                             , mkShuffleVectorInst
                                             , mkInsertValueInst
                                             , mkAllocaInst
                                             , mkLoadInst
                                             , mkStoreInst
                                             , mkConversionInst
                                             , mkIcmpInst
                                             , mkFcmpInst
                                             , mkPhiNode
                                             , mkSelectInst
                                             , mkFlaggedArithInst
                                             , mkArithInst
                                             , mkCallInst
                                             ) where

import Data.ByteString.Lazy (ByteString)

import Data.LLVM.Private.AttributeTypes
import Data.LLVM.Private.PlaceholderTypes

type PartialConstant = Type -> Constant

mkExtractElementInst :: (Monad m) => Identifier -> Type -> PartialConstant -> Constant -> m Instruction
mkExtractElementInst name ty1 v1 v2 =
  case ty1 of
    TypeVector _ t -> return $ namedInst name t $ ExtractElementInst (v1 ty1) v2
    _ -> fail "Non-vector type in extractelement"

mkInsertElementInst :: Identifier -> Type -> PartialConstant -> Constant -> Constant -> Instruction
mkInsertElementInst name tyr val sclr idx =
  namedInst name tyr $ InsertElementInst (val tyr) sclr idx

-- FIXME: Parse the bytestring - have the code for this already in the
-- old attoparsec-based parser
mkDataLayout :: a -> DataLayout
mkDataLayout s = defaultDataLayout

mkShuffleVectorInst :: (Monad m) => Identifier -> Type -> PartialConstant -> Type -> PartialConstant -> Type -> PartialConstant -> m Instruction
mkShuffleVectorInst name t1 val1 t2 val2 t3 mask
  | t1 == t2 =
    case (t1, t3) of
      (TypeVector _ t, TypeVector n _) ->
        return $ namedInst name (TypeVector n t) (ShuffleVectorInst (val1 t1) (val2 t2) (mask t3))
      _ -> fail "Non-vector type for vec or mask in shufflevector"

  | otherwise = fail "Input vector types do not match"

-- FIXME: Add checks to ensure the type of the inserted element is correct
-- based on the index
mkInsertValueInst :: Identifier -> Type -> PartialConstant -> Type -> PartialConstant -> Integer -> Instruction
mkInsertValueInst name t1 v1 t2 v2 idx =
  namedInst name t1 $ InsertValueInst (v1 t1) (v2 t2) idx

mkAllocaInst :: Identifier -> Type -> Constant -> Integer -> Instruction
mkAllocaInst name ty num align =
  namedInst name (TypePointer ty) $ AllocaInst ty num align

-- The type of a load is ty with a layer of pointer type unwrapped.
-- The input *must* be a pointer type
mkLoadInst :: Identifier -> Bool -> Type -> PartialConstant -> Integer -> Instruction
mkLoadInst ident volatile ty val align =
  namedInst ident ty' $ LoadInst volatile (val ty) align
  where (TypePointer ty') = ty

mkStoreInst :: (Monad m) => Bool -> Type -> PartialConstant -> Type -> PartialConstant -> Integer -> m Instruction
mkStoreInst volatile t1 val t2 dest align
  | t2 == t1 = return $ voidInst $ StoreInst volatile (val t1) (dest t2) align
  | otherwise = fail "Store type mismatch"
  where (TypePointer t2') = t2

mkFlaggedArithInst :: (Monad m) => (a -> Constant -> Constant -> InstructionT) -> Identifier -> Type -> a -> PartialConstant -> PartialConstant -> m Instruction
mkFlaggedArithInst inst ident ty flags v1 v2 =
  return $ namedInst ident ty $ inst flags (v1 ty) (v2 ty)

mkArithInst :: (Monad m) => (Constant -> Constant -> InstructionT) -> Identifier -> Type -> PartialConstant -> PartialConstant -> m Instruction
mkArithInst inst ident ty v1 v2 =
  return $ namedInst ident ty $ inst (v1 ty) (v2 ty)

-- Build a conversion instruction using the provided type constructor.
-- Examples: TruncInst, ZextInst
-- These all follow the same pattern: convert a value of t1 to t2.
mkConversionInst :: (Monad m) => (Constant -> Type -> InstructionT) -> Identifier -> Constant -> Type -> m Instruction
mkConversionInst inst ident val t =
  return $ namedInst ident t $ inst val t

mkIcmpInst :: (Monad m) => Identifier -> ICmpCondition -> Type -> PartialConstant -> PartialConstant -> m Instruction
mkIcmpInst ident cond t v1 v2 =
  return $ namedInst ident t' $ ICmpInst cond (v1 t) (v2 t)
  -- The result type is i1 for scalars, or a vector of i1 with one
  -- entry per element in the input vectors
  where t' = case t of
          TypeVector n innerType -> TypeVector n (TypeInteger 1)
          _ -> TypeInteger 1


mkFcmpInst :: (Monad m) => Identifier -> FCmpCondition -> Type -> PartialConstant -> PartialConstant -> m Instruction
mkFcmpInst ident cond t v1 v2 =
  return $ namedInst ident t' $ FCmpInst cond (v1 t) (v2 t)
  -- The result type is i1 for scalars, or a vector of i1 with one
  -- entry per element in the input vectors
  where t' = case t of
          TypeVector n innerType -> TypeVector n (TypeInteger 1)
          _ -> TypeInteger 1

mkPhiNode :: (Monad m) => Identifier -> Type -> [(PartialConstant, Identifier)] -> m Instruction
mkPhiNode ident ty vals =
  return $ namedInst ident ty $ PhiNode (map applicator vals)
  where applicator (pc, id) = (pc ty, id)

-- this doesn't encode the semantics very well (though they are
-- represented).  If selty is a vector i1, then the selection is
-- performed element-wise in the vectors.  That said, this behavior
-- isn't implemented in LLVM yet so it is a moot point, for now.
mkSelectInst :: (Monad m) => Identifier -> Type -> PartialConstant -> Type -> PartialConstant -> Type -> PartialConstant -> m Instruction
mkSelectInst ident selty sel t1 v1 t2 v2 = do
  if t1 /= t2
    then fail "Vectors must be of the same type"
    else mk'
  where mk' = return $ namedInst ident t1 $ SelectInst (sel selty) (v1 t1) (v2 t2)

mkCallInst :: (Monad m) => Maybe Identifier -> Bool -> CallingConvention -> [ParamAttribute] -> Type -> Maybe Type -> PartialConstant -> [Constant] -> [FunctionAttribute] -> m Instruction
mkCallInst mident isTail cc pattrs rtype mftype func params funcAttrs =
  return $ maybeNamedInst mident rtype i
  where i = CallInst { callIsTail = isTail
                     , callConvention = cc
                     , callParamAttrs = pattrs
                     , callRetType = rtype
                     , callFunction = realFunc
                     , callArguments = params
                     , callAttrs = funcAttrs
                     }
        realFunc = case (func rtype, mftype) of
          (ValueRef _, _) -> func rtype
          (_, Just t) -> func t
          _ -> error "Should not have a constant function without full functype"