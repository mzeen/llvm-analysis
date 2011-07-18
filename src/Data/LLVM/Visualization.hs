{-# OPTIONS_GHC -fno-warn-orphans #-}
module Data.LLVM.Visualization ( viewCFG, viewCG ) where

import Data.GraphViz

import Data.LLVM.Types
import Data.LLVM.CFG
import Data.LLVM.CallGraph

viewCFG :: CFG -> IO ()
viewCFG cfg = do
  let params = nonClusteredParams { fmtNode = \(_,l) -> [toLabel (Value l)]
                                  , fmtEdge = \(_,_,l) -> [toLabel (l)]
                                  }
      dg = graphToDot params (cfgGraph cfg)
  _ <- runGraphvizCanvas' dg Gtk
  return ()

viewCG :: CallGraph -> IO ()
viewCG cg = do
  let params = nonClusteredParams { fmtNode = \(_,l) -> [toLabel (l)]
                                  , fmtEdge = \(_,_,l) -> [toLabel (l)]
                                  }
      dg = graphToDot params (callGraphRepr cg)
  _ <- runGraphvizCanvas' dg Gtk
  return ()
