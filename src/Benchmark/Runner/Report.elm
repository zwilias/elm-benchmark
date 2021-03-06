module Benchmark.Runner.Report exposing (..)

import Benchmark.Reporting as Reporting exposing (Report(..))
import Benchmark.Runner.Box as Box
import Benchmark.Runner.Humanize as Humanize
import Benchmark.Runner.Text as Text
import Benchmark.Status as Status exposing (Status(..))
import Element exposing (..)
import Element.Attributes exposing (..)
import Style exposing (..)
import Style.Font as Font
import Style.Sheet as Sheet
import Time
import Trend.Linear as Trend exposing (Quick, Trend)


view : Report -> Element Class Variation msg
view report =
    report
        |> reports []
        |> (::) (Text.hero TextClass "Benchmark Report")
        |> column Unstyled []


reports : List String -> Report -> List (Element Class Variation msg)
reports reversedParents report =
    case report of
        Single name status ->
            [ singleReport
                (List.reverse reversedParents)
                name
                status
            ]

        Series name statuses ->
            [ multiReport
                (List.reverse reversedParents)
                name
                statuses
            ]

        Group name children ->
            children
                |> List.map (reports (name :: reversedParents))
                |> List.concat


singleReport : List String -> String -> Status -> Element Class Variation msg
singleReport parents name status =
    trendFromStatus status
        |> Maybe.map
            (\trend ->
                [ [ header Text "runs / second", runsPerSecond Text trend ]
                , [ header Numeric "goodness of fit", goodnessOfFit trend ]
                ]
            )
        |> Maybe.map (report parents name)
        |> Maybe.withDefault empty


multiReport : List String -> String -> List ( String, Status ) -> Element Class Variation msg
multiReport parents name children =
    let
        ( names, statuses ) =
            List.unzip children
    in
    trendsFromStatuses statuses
        |> Maybe.map
            (\trends ->
                [ header Text "name" :: List.map (cell Text) names
                , header Numeric "runs / second" :: List.map (runsPerSecond Numeric) trends
                , List.map2 percentChange
                    trends
                    (List.drop 1 trends)
                    |> (::) (cell Numeric "-")
                    |> (::) (header Numeric "% change")
                , header Numeric "goodness of fit" :: List.map goodnessOfFit trends
                ]
            )
        |> Maybe.map (report parents name)
        |> Maybe.withDefault empty


report : List String -> String -> List (List (Element Class Variation msg)) -> Element Class Variation msg
report parents name tableContents =
    column Unstyled
        [ paddingTop Box.spaceBetweenSections ]
        [ Text.path TextClass parents
        , column Box
            [ paddingXY Box.barPaddingX Box.barPaddingY
            , width (px 500)
            ]
            [ text name
            , table
                Table
                [ width (percent 100)
                , paddingTop 10
                ]
                tableContents
            ]
        ]


runsPerSecond : Variation -> Trend Quick -> Element Class Variation msg
runsPerSecond variation =
    Trend.line
        >> flip Trend.predictX Time.second
        >> floor
        >> Humanize.int
        >> cell variation


percentChange : Trend Quick -> Trend Quick -> Element Class Variation msg
percentChange old new =
    let
        rps =
            Trend.line >> flip Trend.predictX Time.second

        change =
            (rps new - rps old) / rps new

        sign =
            if change > 0 then
                "+"
            else
                ""
    in
    if old == new then
        cell Numeric "-"
    else
        Humanize.percent change
            |> (++) sign
            |> cell Numeric


goodnessOfFit : Trend Quick -> Element Class Variation msg
goodnessOfFit =
    Trend.goodnessOfFit
        >> Humanize.percent
        >> cell Numeric


trendFromStatus : Status -> Maybe (Trend Quick)
trendFromStatus status =
    case status of
        Success _ trend ->
            Just trend

        _ ->
            Nothing


trendsFromStatuses : List Status -> Maybe (List (Trend Quick))
trendsFromStatuses =
    List.foldr
        (\this acc ->
            Maybe.map2
                (::)
                (trendFromStatus this)
                acc
        )
        (Just [])


header : Variation -> String -> Element Class Variation msg
header variation caption =
    el Header [ vary variation True ] (text caption)


cell : Variation -> String -> Element Class Variation msg
cell variation contents =
    el Cell
        [ vary variation True
        , paddingTop 5
        ]
        (text contents)


type Class
    = Unstyled
    | Box
    | Table
    | Header
    | Cell
    | TextClass Text.Class


type Variation
    = Numeric
    | Text


styles : List (Style Class Variation)
styles =
    [ style Unstyled []
    , style Box Box.style
    , style Table [ prop "font-feature-settings" "'tnum'" ]
    , style Header
        [ Font.bold
        , Font.size 12
        , variation Numeric [ Font.alignRight ]
        , variation Text [ Font.alignLeft ]
        ]
    , style Cell
        [ Font.size 18
        , variation Numeric [ Font.alignRight ]
        , variation Text [ Font.alignLeft ]
        ]
    , Text.styles
        |> Sheet.map TextClass identity
        |> Sheet.merge
    ]
