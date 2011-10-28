import System.Environment ( getArgs )

import Data.LLVM.Analysis.PointsTo.Andersen
import Data.LLVM.ParseBitcode

main :: IO ()
main = do
  [ fname ] <- getArgs
  mm <- parseLLVMBitcodeFile defaultParserOptions fname
  case mm of
    Left err -> putStrLn err
    Right m -> do
      let a = runPointsToAnalysis m
      viewPointsToGraph a
      return ()
