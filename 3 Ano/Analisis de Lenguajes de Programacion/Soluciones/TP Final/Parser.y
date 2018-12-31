{
module Parser where

import Types 
import Data.Char (isAlpha, isDigit, isSpace)
import UI.NCurses (Color (..))
}

%name parse
%tokentype { Token }
%error { parseError }

%token
  Chebyshev     { TChebyshev }
  Manhattan     { TManhattan }
  State         { TState }
  Black         { TBlack }
  Red           { TRed }
  Green         { TGreen }
  Yellow        { TYellow }
  Blue          { TBlue }
  Magenta       { TMagenta }
  Cyan          { TCyan }
  White         { TWhite }
  ':'           { TColon }
  ','           { TSemiColon }
  '\''          { TApostrophe }
  '('           { TPOpen }
  ')'           { TPClose }
  Int           { TInt $$ }
  Char          { TChar $$ }
  Eq            { TEq }
  Neq           { TNeq }
  Leq           { TLeq }
  Geq           { TGeq }
  Lower         { TLower }
  Greater       { TGreater }
  And           { TAnd } 
  North         { TNorth }
  South         { TSouth }
  East          { TEast }
  West          { TWest }
  NW            { TNW }
  NE            { TNE }
  SE            { TSE }
  SW            { TSW }

%%

Automata   ::                                                               { ([(Char,Char,Color,Color)], [Rule]) }
Automata   : States Rules                                                   { ($1, $2) }

States     ::                                                               { [(Char,Char,Color,Color)] }
States     : '\'' Char '\'' ':' '\'' Char '\'' Color Color States           { ($2, $6, $8, $9) : $10 }
           | {- empty -}                                                    { [] }

Color      ::                                                               { Color }
Color      : Black                                                          { ColorBlack }
           | Red                                                            { ColorRed }
           | Green                                                          { ColorGreen }
           | Yellow                                                         { ColorYellow }
           | Blue                                                           { ColorBlue }
           | Magenta                                                        { ColorMagenta }
           | Cyan                                                           { ColorCyan }
           | White                                                          { ColorWhite }

Rules      ::                                                               { [Rule] }
Rules      : State Eq '\'' Char '\'' ':' '\'' Char '\'' Rules               { ([State $4], $8) : $10 }
	   | State Eq '\'' Char '\'' Comparsion ':' '\'' Char '\'' Rules    { ((State $4 : $6), $9) : $11  }
           | {- empty -}                                                    { [] }

Comparsion ::                                                               { [Condition] }
Comparsion : And Distance '(' '\'' Char '\'' ',' Int ')' Cmp Int Comparsion { (Chebyshev $5 $8 $10 $11) : $12 } 
	   | And Cardinal '(' Int ')' Cmp '\'' Char '\'' Comparsion         { ($2 $4 $6 $8) : $10 }
	   | {- empty -}                                                    { [] }

Distance   ::                                                               { Char -> Int -> (Int -> Int -> Bool) -> Int -> Condition }
Distance   : Chebyshev                                                      { Chebyshev }
	   | Manhattan                                                      { Manhattan }

Cardinal   ::                                                               { Int -> (Char -> Char -> Bool) -> Char -> Condition } 
Cardinal   : North                                                          { North }
	   | South                                                          { South }
           | East                                                           { East }
           | West                                                           { West }
           | NE                                                             { NE }
           | NW                                                             { NW }
           | SE                                                             { SE }
           | SW                                                             { SW }

Cmp        ::                                                               { forall a. (Ord a) => a -> a -> Bool }
Cmp        : Eq                                                             { (==) }
	   | Leq                                                            { (<=) }
           | Geq                                                            { (>=) }
           | Lower                                                          { (<)  }
           | Greater                                                        { (>)  }
           | Neq                                                            { (/=) }

{
parseError :: [Token] -> a
parseError ts = error $ "La lista de tokens es: " ++ show ts

lexer :: String -> [Token]
lexer [] = []
lexer ('\'':c:'\'':cs) = TApostrophe : (TChar c) : TApostrophe : lexer cs
lexer ('&':'&':cs) = TAnd : lexer cs
lexer ('=':'=':cs) = TEq : lexer cs
lexer ('/':'=':cs) = TNeq : lexer cs
lexer ('>':'=':cs) = TGeq : lexer cs
lexer ('<':'=':cs) = TLeq : lexer cs
lexer ('<':cs)     = TLower : lexer cs
lexer ('>':cs)     = TGreater : lexer cs
lexer ('(':cs)     = TPOpen : lexer cs
lexer (')':cs)     = TPClose : lexer cs
lexer (',':cs)     = TSemiColon : lexer cs
lexer (c:cs)
      | isSpace c  = lexer cs
      | isAlpha c  = lexVar (c:cs)
      | isDigit c  = lexNum (c:cs)
lexer (':':cs)     = TColon : lexer cs

lexNum cs = TInt (read num) : lexer rest where
            (num, rest) = span isDigit cs

lexVar cs = case span isAlpha cs of
            ("Neighbours", rest) -> TNeighbours : lexer rest
            ("Chebyshev", rest)  -> TChebyshev : lexer rest
            ("Manhattan", rest)  -> TManhattan : lexer rest
            ("State", rest)      -> TState : lexer rest
            ("Black", rest)      -> TBlack : lexer rest
            ("Red", rest)        -> TRed : lexer rest
            ("Green", rest)      -> TGreen : lexer rest
            ("Yellow", rest)     -> TYellow : lexer rest
            ("Blue", rest)       -> TBlue : lexer rest
            ("Magenta", rest)    -> TMagenta : lexer rest
            ("Cyan", rest)       -> TCyan : lexer rest
            ("White", rest)      -> TWhite : lexer rest
            ("North", rest)      -> TNorth : lexer rest
            ("South", rest)      -> TSouth : lexer rest
            ("East", rest)       -> TEast : lexer rest
            ("West", rest)       -> TWest : lexer rest
            ("NW", rest)         -> TNW : lexer rest
            ("NE", rest)         -> TNE : lexer rest
            ("SW", rest)         -> TSW : lexer rest
            ("SE", rest)         -> TSE : lexer rest
}
