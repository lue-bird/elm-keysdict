module Order.Test exposing (tests)

import Char.Order
import Expect
import Fuzz exposing (Fuzzer)
import Int.Order
import Order
import Test exposing (Test)


tests : Test
tests =
    Test.describe "Order"
        [ let
            unicodeNonLetter : Fuzzer Char
            unicodeNonLetter =
                Fuzz.char
                    |> Fuzz.filter
                        (\c ->
                            (c |> Char.isLower |> not) && (c |> Char.isUpper |> not)
                        )
          in
          Test.fuzz
            (Fuzz.pair unicodeNonLetter unicodeNonLetter)
            "non-letter: Char.Order.alphabetically = Order.by Char.toCode Int.Order.increasing"
            (\( char0, char1 ) ->
                Order.with
                    (Char.Order.alphabetically Char.Order.upperLower)
                    char0
                    char1
                    |> Expect.equal
                        (Order.with
                            (Order.by Char.toCode Int.Order.increasing)
                            char0
                            char1
                        )
            )
        ]
