module Float.Order exposing (increasing, Increasing, decreasing)

{-| `Order` `Float`s

@docs increasing, Increasing, decreasing

-}

import Order exposing (Ordering)
import Typed


{-| Tag for [`increasing`](#increasing)
-}
type Increasing
    = Increasing


{-| `Order` `Float`s where lower means greater

    import Order

    Order.with Float.Order.increasing 40.34 2.1
    --> GT

-}
increasing : Ordering Float Increasing
increasing =
    Typed.tag Increasing (\( a, b ) -> compare a b)


{-| `Order` `Float`s where higher means greater

    import Order

    Order.with Float.Order.decreasing 2.1 40.34
    --> GT

-}
decreasing : Ordering Float (Order.Reverse Increasing)
decreasing =
    increasing |> Order.reverse
