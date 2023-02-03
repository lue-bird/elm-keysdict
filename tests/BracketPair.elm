module BracketPair exposing (BracketPair, ByOpenClosed, byOpenClosed)

import Char.Order
import Keys
import Map exposing (Mapping)
import N exposing (N0, N1, To, Up)
import Order
import Typed


type alias ByOpenClosed =
    ( ( ()
      , Order.By
            Open
            (Char.Order.Alphabetically Char.Order.LowerUpper)
      )
    , Order.By
        Closed
        (Char.Order.Alphabetically Char.Order.LowerUpper)
    )


type alias BracketPair =
    { open : Char, closed : Char }


type Open
    = Open


type Closed
    = Closed


byOpenClosed :
    Keys.Keys
        BracketPair
        ByOpenClosed
        { open : Keys.Key BracketPair Char (Up N1 To N1)
        , closed : Keys.Key BracketPair Char (Up N0 To N1)
        }
        N1
byOpenClosed =
    Keys.for (\open_ closed_ -> { open = open_, closed = closed_ })
        |> Keys.by ( .open, open )
            (Char.Order.alphabetically Char.Order.lowerUpper)
        |> Keys.by ( .closed, closed )
            (Char.Order.alphabetically Char.Order.lowerUpper)


open : Mapping BracketPair Open Char
open =
    Typed.tag Open .open


closed : Mapping BracketPair Closed Char
closed =
    Typed.tag Closed .closed
