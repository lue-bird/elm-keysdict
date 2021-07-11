# `KeysDict`
> Lookup elements by their unique aspects.

For a `KeysDict` with some elements
```elm
{ flag = "🇦🇺", code = "AU", name = "Australia" }
{ flag = "🇦🇶", code = "AQ", name = "Antarctica" }
{ flag = "🇱🇧", code = "LB", name = "Lebanon" }
```
you can specify aspects that will be unique across all elements.
```elm
KeysDict.promising
    [ unique .flag, unique .code ]
```
If you have a key and the aspect to check if it matches, you can find the matching element:

```elm
KeysDict.at .flag "🇦🇶"
--> Just { flag = "🇦🇶", code = "AQ", name = "Antarctica" }

KeysDict.at .code "LB"
--> Just { flag = "🇱🇧", code = "LB", name = "Lebanon" }
```

&nbsp;


## 👍 How to

### example

```elm
import KeysDict.Uniqueness exposing (unique)
import KeysDict exposing (KeysDict)

type alias Account =
    { username : String
    , email : String
    , settings : Settings
    }

type alias Model =
    { accounts : KeysDict Account }


initialModel =
    { accounts =
        KeysDict.promising
            [ unique .atomicNumber, unique .symbol ]
    }

update msg model =
    case msg of
        LoggedIn username ->
            { model | selectedUsername = username }
        
        Registered username email ->
            if
                model.accounts
                    |> KeysDict.any (.username >> (==) username)
            then
                -- username already taken

            else
                { model
                  | accounts =
                      model.accounts
                          |> KeysDict.insert
                              { username = username
                              , email = email
                              , settings = defaultSettings
                              }
                }
            
        ChangedSettings updateSettings username ->
            { model
              | accounts =
                  model.accounts
                      |> KeysDict.update .username username
                          updateSettings
            }
```

### Example: brackets

```elm
brackets =
    KeysDict.promising
        [ unique .opening, unique .closing ]
        |> KeysDict.insertAll
            [ { opening = '(', closing = ')' }
            , { opening = '{', closing = '}' }
            ]

{-| closes/opens with the opposite bracket.
-}
typeChar character =
    case
        brackets
            |> KeysDict.at .opening character
    of
        Just { closing }->
            String.fromList [ character, closing ]

        Nothing->
            case
                brackets
                    |> KeysDict.at .closing character
            of
                Just { opening }->
                    String.fromList [ opening, character ]
                  
                Nothing->
                    String.fromChar character

"Typing (: " ++ typeChar '(' ++ ". Even }: " ++ typeChar '}'
```
&nbsp;


## 👎 How not to

## Example: automatic answers
```elm
answers =
    KeysDict.promising [ unique .youSay ]
        |> KeysDict.insertAll
            [ { youSay = "Hi"
              , answer = "Hi there!"
              }
            , { youSay = "Bye"
              , answer = "Ok, have a nice day and spread some love."
              }
            , { youSay = "How are you"
              , answer = "I don't have feelings :("
              }
            , { youSay = "Are you a robot"
              , answer = "I think the most human answer is 'Haha... yes'"
              }
            ]
```
We will only ever lookup answers to what `youSay`
→ use a `Dict` where it is more appropriate: **`Dict`s are for one-way access**.

## Example: translation, synonymes...
```elm
translationsEnDe =
    KeysDict.promising []
        |> KeysDict.insertAll
            [ { english = "elm", german = "Ulme" }
            , { english = "git", german = "Schwachkopf" }
            , { german = "Rüste", english = "elm" }
            ]
```
A `KeysDict` is only effective when there is **only one matching key**.

Please take a look at [elm-bidict](https://github.com/Janiczek/elm-bidict) instead!

## Example: partners, opposites...

Similar to the previous example:
```elm
partners =
    KeysDict.promising
        [ unique .partner, unique .partnerOfPartner ]
        |> KeysDict.insertAll
            [ { partner = "Ann", partnerOfPartner = "Alan" }
            , { partner = "Alex", partnerOfPartner = "Alastair" }
            , { partner = "Alan", partnerOfPartner = "Ann" }
            -- wait, this is no duplicate and is inserted
            ]
```
A `KeysDict` ony makes sense when the **keys describe something different**.
