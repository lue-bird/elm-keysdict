# change log

#### 3.0.3

- `miniBill/elm-generic-dict` disadvantages correct

#### 3.0.2

- `linear-direction` → >= 11.0.0
- `typesafe-array` → >= 30.0.0

#### 3.0.1

- readme goodies add

## 3.0.0

- `KeySet`, `KeysSet` merge
    - 👍 `KeysSet` functionality while still running in `log n`
    - 👎 more complex API
    - `elementRemove` name → `remove`
    - `only` name → `one`
    - `mapTry` type result keep `possiblyOrNever`
- `.Order` modules move from `linear-direction`
    - `module Maybe.Order` remove
    - `module Case` move into `Char.Linear`
    - `on` add
    - integrate tag into `Order`, so that simple sets don't require opaque tags,
    for example
    ```elm
    intKeys : Keys.Identity Int Int.Order.Increasing
    intKeys =
        Keys.identity Int.Order.increasing
    ```
        - 👎 chaining with `onTie` is a bit more verbose than `onTieNext [ ... ]`
        - 👍 chaining with `onTie` is more obvious and easier to read than `onTieNext [ ... ]`

#### 2.1.1

- readme `KeySet` example ordering correct

### 2.1.0

- `KeySet` add

## 2.0.0

- indirection `ElementsWithUniquenessPromises` remove
- `when` remove
    - in favor of `mapTry`
- `set |> isUnique element` → `element |> allDifferentFrom set`
- `equal a b` → `a |> isEqualTo b`
- `at door key` → `element ( door, key )`
- `update door key` → `elementAlter ( door, key )`
- `updateAll` name → `alter`
- `remove` name → `elementRemove`
- `insertAll` name → `insertList`
- `mapTry` add
- `lue-bird/elm-typed-value` dependency remove
    - in favor of opaque `type` immune to internal changes
- performance improve

## 1.0.0

- removed `KeysDict.toDict`
- removed `KeysDict.serialize`
- removed `KeysDict.Uniqueness.violated`
- changed `KeysDict.enterBy { door, key }` to `at door key`
- changed `KeysDict.remove { door, key }` to `remove door key`

- renamed `KeysDict` to `KeysSet`
- moved `KeysDict.Uniqueness.Uniqueness` to `KeysSet.Uniqueness`
- moved `KeysDict.Uniqueness.unique` to `KeysSet.unique`
- renamed `KeysDict.foldHouses` to `fold`
- renamed `KeysDict.countHouses` to `size`
- renamed `KeysDict.houses` to `toList`
- renamed `KeysDict.enterableBy` to `promising`

- added `KeysSet.insertAll`
- added `KeysSet.update`
- added `KeysSet.updateAll`
- added `KeysSet.where`
- added `KeysSet.isUnique`
- added `KeysSet.all`
- added `KeysSet.any`
- added `KeysSet.isEmpty`

## before
[indique/elm-keysdict](https://package.elm-lang.org/packages/indique/elm-keysdict/latest/) → `lue-bird/elm-keysset`
