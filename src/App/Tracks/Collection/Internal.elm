module Tracks.Collection.Internal
    exposing
        ( build
        , buildf
        , partial
        , initialize
        , identify
        , harvest
        , expose
        )

import List.Extra as List
import Tracks.Favourites as Favourites
import Tracks.Sorting as Sorting
import Tracks.Types exposing (..)


build : List Track -> Parcel -> Parcel
build tracks =
    initialize tracks >> identify >> harvest >> expose


buildf : Parcel -> List Track -> Parcel
buildf =
    flip build


partial : Int
partial =
    50



-- Initialize


initialize : List Track -> Parcel -> Parcel
initialize tracks ( model, collection ) =
    (,) model { collection | untouched = tracks }



-- Identifying


identify : Parcel -> Parcel
identify ( model, collection ) =
    let
        ( identifiedUnsorted, missingFavourites ) =
            List.foldl
                (identifier model.favourites)
                ( [], model.favourites )
                collection.untouched
    in
        identifiedUnsorted
            |> List.append (List.map makeMissingFavouriteTrack missingFavourites)
            |> Sorting.sort model.sortBy model.sortDirection
            |> (\x -> { collection | identified = x })
            |> (\x -> (,) model x)


identifier :
    List Favourite
    -> Track
    -> ( List IdentifiedTrack, List Favourite )
    -> ( List IdentifiedTrack, List Favourite )
identifier favourites track ( acc, missingFavourites ) =
    let
        lartist =
            String.toLower track.tags.artist

        ltitle =
            String.toLower track.tags.title

        idx =
            List.findIndex (Favourites.matcher lartist ltitle) missingFavourites
    in
        case idx of
            Just i ->
                ( acc
                    ++ [ ( { isFavourite = True
                           , isMissing = False
                           , isNowPlaying = False
                           }
                         , track
                         )
                       ]
                , List.removeAt i missingFavourites
                )

            Nothing ->
                ( acc
                    ++ [ ( { isFavourite = False
                           , isMissing = False
                           , isNowPlaying = False
                           }
                         , track
                         )
                       ]
                , missingFavourites
                )


makeMissingFavouriteTrack : Favourite -> IdentifiedTrack
makeMissingFavouriteTrack fav =
    let
        tags =
            { disc = 1
            , nr = 0
            , artist = fav.artist
            , title = fav.title
            , album = "<missing>"
            , genre = Nothing
            , year = Nothing
            }
    in
        (,)
            { isFavourite = True, isMissing = True, isNowPlaying = False }
            { tags = tags, id = "<missing>", path = "<missing>", sourceId = "<missing>" }



-- Harvesting


harvest : Parcel -> Parcel
harvest ( model, collection ) =
    let
        harvested =
            case model.searchResults of
                Just [] ->
                    []

                Just trackIds ->
                    collection.identified
                        |> List.foldl harvester ( [], trackIds )
                        |> Tuple.first

                Nothing ->
                    collection.identified

        filtered =
            if model.favouritesOnly then
                List.filter (\( i, t ) -> i.isFavourite == True) harvested
            else
                List.filter (\( i, t ) -> i.isMissing == False) harvested
    in
        (,)
            model
            { collection | harvested = filtered }


harvester :
    IdentifiedTrack
    -> ( List IdentifiedTrack, List TrackId )
    -> ( List IdentifiedTrack, List TrackId )
harvester ( i, t ) ( acc, trackIds ) =
    case List.findIndex ((==) t.id) trackIds of
        Just idx ->
            ( acc ++ [ ( i, t ) ]
            , List.removeAt idx trackIds
            )

        Nothing ->
            ( acc
            , trackIds
            )



-- Exposing


expose : Parcel -> Parcel
expose ( model, collection ) =
    (,)
        model
        { collection | exposed = List.take (model.exposedStep * partial) collection.harvested }
