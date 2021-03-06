module Tracks.Collection.Responses exposing (..)

import Tracks.Encoding
import Tracks.Ports as Ports
import Tracks.Types exposing (..)
import Types as TopLevel
import Users.Data
import Utils exposing (do)


{-| Consequences when changing `collection.untouched`.
-}
globalConsequences : Collection -> Collection -> Model -> Cmd TopLevel.Msg
globalConsequences oldCollection newCollection model =
    case oldCollection.untouched /= newCollection.untouched of
        True ->
            let
                encodedTracks =
                    List.map Tracks.Encoding.encodeTrack newCollection.untouched
            in
            Cmd.batch
                [ Users.Data.storeTracks encodedTracks
                , Ports.updateSearchIndex encodedTracks
                , do (TopLevel.TracksMsg (Search model.searchTerm))
                ]

        False ->
            Cmd.none


{-| Consequences when changing `collection.harvested`.
-}
harvestingConsequences : Collection -> Collection -> Model -> Cmd TopLevel.Msg
harvestingConsequences oldCollection newCollection _ =
    case oldCollection.harvested /= newCollection.harvested of
        True ->
            do TopLevel.ResetQueue

        False ->
            Cmd.none
