module Simplytyped (
       conversion,    -- conversion a terminos localmente sin nombre
       eval,          -- evaluador
       infer,         -- inferidor de tipos
       quote          -- valores -> terminos
       )
       where

import Data.List
import Data.Maybe
import Prelude hiding ((>>=))
import Text.PrettyPrint.HughesPJ (render)
import PrettyPrinter
import Common

-- conversion a términos localmente sin nombres
conversion :: LamTerm -> Term
conversion = conversion' []

conversion' :: [String] -> LamTerm -> Term
conversion' b (LVar n)     = maybe (Free (Global n)) Bound (n `elemIndex` b)
conversion' b (App t u)    = conversion' b t :@: conversion' b u
conversion' b (Abs n t u)  = Lam t (conversion' (n:b) u)
conversion' b (LetL s t u) = Let (Global s) (conversion' b t) (conversion' b u)
conversion' b (AsL s t)    = As (conversion' b s) t
conversion' b (UnitL)      = Unit
conversion' b (PairL t u)  = Pair (conversion' b t) (conversion' b u)
conversion' b (FstL s)     = Fst $ conversion' b s
conversion' b (SndL s)     = Snd $ conversion' b s
conversion' b (ZeroL)      = Zero
conversion' b (SucL s)     = Suc $ conversion' b s
conversion' b (RecL s t u) = Rec (conversion' b s) (conversion' b t) (conversion' b u)

-----------------------
--- eval
-----------------------

sub :: Int -> Term -> Term -> Term
sub i t (Bound j) | i == j    = t
sub _ _ (Bound j) | otherwise = Bound j
sub _ _ (Free n)              = Free n
sub i t (u :@: v)             = sub i t u :@: sub i t v
sub i t (Lam t' u)            = Lam t' (sub (i + 1) t u)
sub i t (Let s u v)           = Let s (sub i t u) (sub i t v)
sub i t (As u v)              = As (sub i t u) v
sub i t (Unit)                = Unit
sub i t (Pair u v)            = Pair (sub i t u) (sub i t v)
sub i t (Fst s)               = Fst $ sub i t s
sub i t (Snd s)               = Snd $ sub i t s
sub i t (Zero)                = Zero
sub i t (Suc s)               = Suc $ sub i t s
sub i t (Rec s u v)           = Rec (sub i t s) (sub i t u) (sub i t v)

-- evaluador de términos
eval :: NameEnv Value Type -> Term -> Value
eval _ (Bound _)             = error "variable ligada inesperada en eval"
eval e (Free n)              = fst $ fromJust $ lookup n e
eval _ (Lam t u)             = VLam t u
eval e (Lam _ u :@: Lam s v) = eval e (sub 0 (Lam s v) u)
eval e (Lam t u :@: v)       = case eval e v of
                 VLam t' u'  -> eval e (Lam t u :@: Lam t' u')
                 VUnit       -> eval e $ sub 0 Unit u
                 VPair t' u' -> eval e $ sub 0 (Pair (quote t') (quote u')) u
                 VNat n      -> eval e $ sub 0 (quote $ VNat n) u
eval e (u :@: v)             = case eval e u of
                 VLam t u' -> eval e (Lam t u' :@: v)
                 _         -> error "Error de tipo en run-time, verificar type checker"
eval e (Let s u v)           = let u' = eval e u
                                   Right t = infer [] (quote u')
                               in eval ((s, (u', t)):e) v
eval e (As s t)              = eval e s
eval e (Unit)                = VUnit
eval e (Pair u v)            = VPair (eval e u) (eval e v)
eval e (Fst (Pair u v))      = eval e u
eval e (Snd (Pair u v))      = eval e v
eval e (Zero)                = VNat VZero
eval e (Suc t)               = case (eval e t) of
                               VNat x -> VNat $ VSuc x
                               _ -> error "Error de tipo en run-time, verificar type checker"
eval e (Rec s u v)           = case eval e v of
                               VNat VZero    -> eval e s
                               VNat (VSuc x) -> eval e $ u :@: (Rec s u v') :@: v'
                                                where v' = quote $ VNat x
                               _ -> error "Error de tipo en run-time, verificar type checker"

-----------------------
--- quoting
-----------------------

quote :: Value -> Term
quote (VLam t f)      = Lam t f
quote (VUnit)         = Unit
quote (VPair u v)     = Pair (quote u) (quote v)
quote (VNat VZero)    = Zero
quote (VNat (VSuc x)) = Suc $ quote $ VNat x

----------------------
--- type checker
-----------------------

-- type checker
infer :: NameEnv Value Type -> Term -> Either String Type
infer = infer' []

-- definiciones auxiliares
ret :: Type -> Either String Type
ret = Right

err :: String -> Either String Type
err = Left

(>>=) :: Either String Type -> (Type -> Either String Type) -> Either String Type
(>>=) v f = either Left f v
-- fcs. de error

matchError :: Type -> Type -> Either String Type
matchError t1 t2 = err $ "se esperaba " ++
                         render (printType t1) ++
                         ", pero " ++
                         render (printType t2) ++
                         " fue inferido."

notfunError :: Type -> Either String Type
notfunError t1 = err $ render (printType t1) ++ " no puede ser aplicado."

notfoundError :: Name -> Either String Type
notfoundError n = err $ show n ++ " no está definida."

infer' :: Context -> NameEnv Value Type -> Term -> Either String Type
infer' c _ (Bound i) = ret (c !! i)
infer' _ e (Free n) = maybe (notfoundError n) (ret . snd) (lookup n e)
infer' c e (t :@: u) = infer' c e t >>= \tt ->
                       infer' c e u >>= \tu ->
                       case tt of Fun t1 t2 -> if tu == t1
                                               then ret t2
                                               else matchError t1 tu
                                  _         -> notfunError tt
infer' c e (Lam t u) = infer' (t:c) e u >>= (ret . Fun t)
infer' c e (Let s u v) = infer' c e u >>= \u' ->
                         infer' c ((s, ((eval e u), u')):e) v
infer' c e (As u t) = infer' c e u >>= \t' ->
                      if t' == t then ret t else matchError t t'
infer' c e (Unit) = ret UnitT
infer' c e (Pair u v) = infer' c e u >>= \tu ->
                        infer' c e v >>= \tv ->
                        ret $ PairT tu tv
infer' c e (Fst s) = infer' c e s >>= \t ->
                     case t of PairT x y -> ret x
                               _         -> err "No se puede aplicar fst a algo que no es una tupla"
infer' c e (Snd s) = infer' c e s >>= \t ->
                     case t of PairT x y -> ret y
                               _         -> err "No se puede aplicar snd a algo que no es una tupla"
infer' c e (Zero) = ret NatT
infer' c e (Suc s) = infer' c e s >>= \s' -> if s' == NatT then ret NatT else matchError NatT s'
infer' c e (Rec t1 t2 t3) = infer' c e t1 >>= \t1' ->
                            infer' c e t2 >>= \t2' ->
                            infer' c e t3 >>= \t3' ->
                            if t3' == NatT
                            then case t2' of
                                 Fun x (Fun NatT z) -> if x == t1' && z == t1'
                                                       then ret t1' else notfunError t2'
                                 _                  -> notfunError t2'
                            else matchError NatT t1'
----------------------------------
