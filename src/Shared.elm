port module Shared exposing
    ( Flags
    , Model
    , Msg
    , decodeWS
    , init
    , responseReceiver
    , sendAction
    , sendActions
    , subscriptions
    , update
    , view
    )

--modules

import Browser.Navigation exposing (Key, pushUrl)
import Components.Frame
import Element exposing (..)
import Json.Decode as D
import List.Extra exposing (unique)
import Method exposing (Method(..))
import Request exposing (Params, Property(..), request)
import SingleSlider exposing (SingleSlider)
import Spa.Document exposing (Document)
import Spa.Generated.Route as Route exposing (Route)
import Time
import Url exposing (Url)
import WSDecoder exposing (SourceObj, TvshowObj, AlbumObj, ArtistObj, Connection(..), ItemDetails, MovieObj, PType(..), ParamsResponse, PlayerObj(..), ResultResponse(..), SongObj, paramsResponseDecoder, resultResponseDecoder)



-- INIT


type alias Flags =
    { innerWidth : Int
    , innerHeight : Int
    }


type alias Model =
    { flags : Flags
    , url : Url
    , key : Key
    , connection : Connection
    , rightSidebarExtended : Bool
    , controlMenu : Bool
    , players : List PlayerObj
    , currentlyPlaying : Maybe ItemDetails
    , playing : Bool
    , artist_list : List ArtistObj
    , album_list : List AlbumObj
    , song_list : List SongObj
    , genre_list : List String
    , movie_list : List MovieObj
    , tvshow_list : List TvshowObj
    , source_list : List SourceObj
    , volumeSlider : SingleSlider Msg
    , progressSlider : SingleSlider Msg
    , windowWidth : Int
    , windowHeight : Int
    , searchString : String
    }


init : Flags -> Url -> Key -> ( Model, Cmd Msg )
init flags url key =
    ( { flags = flags
      , url = url
      , key = key
      , connection = NotAsked
      , rightSidebarExtended = False
      , controlMenu = False
      , players = []
      , currentlyPlaying = Nothing
      , playing = False
      , artist_list = []
      , album_list = []
      , song_list = []
      , genre_list = []
      , movie_list = []
      , tvshow_list = []
      , source_list = []
      , volumeSlider =
            SingleSlider.init
                { min = 0
                , max = 100
                , value = 50
                , step = 1
                , onChange = VolumeSliderChange
                }
      , progressSlider =
            SingleSlider.init
                { min = 0
                , max = 100
                , value = 1
                , step = 1
                , onChange = ProgressSliderChange
                }
      , windowWidth = flags.innerWidth
      , windowHeight = flags.innerHeight
      , searchString = ""
      }
    , sendActions
        [ """{"jsonrpc": "2.0", "method": "AudioLibrary.GetSongs", "params": { "properties": [ "artist", "duration", "album", "track", "genre", "albumid" ] }, "id": "libSongs"}"""
        , """{"jsonrpc": "2.0", "method": "AudioLibrary.GetAlbums", "params": { "properties": ["playcount", "artist", "genre", "rating", "thumbnail", "year", "mood", "style", "dateadded"] }, "id": "libAlbums"}"""
        , """{"jsonrpc": "2.0", "method": "AudioLibrary.GetArtists", "params": { "properties": [ "thumbnail", "fanart", "born", "formed", "died", "disbanded", "yearsactive", "mood", "style", "genre" ] }, "id": 1}"""
        , """{"jsonrpc": "2.0", "method": "VideoLibrary.GetMusicVideos", "params": { "properties": [ "title", "thumbnail", "artist", "album", "genre", "lastplayed", "year", "runtime", "fanart", "file", "streamdetails" ] }, "id": "libMusicVideos"}"""
        , """{"jsonrpc": "2.0", "method": "VideoLibrary.GetMovies", "params": { "properties" : ["art", "rating", "thumbnail", "playcount", "file"] }, "id": "libMovies"}"""
        , """{"jsonrpc": "2.0", "method": "VideoLibrary.GetTVShows", "params": { "properties": ["art", "genre", "plot", "title", "originaltitle", "year", "rating", "thumbnail", "playcount", "file", "fanart"] }, "id": "libTvShows"}"""
        , """{"jsonrpc": "2.0", "params": {"media": "video"}, "method": "Files.GetSources", "id": 1}"""
        , """{"jsonrpc": "2.0", "params": {"media": "music"}, "method": "Files.GetSources", "id": 1}"""
        ]
    )



-- PORTS


port sendActions : List String -> Cmd msg



--single cmd


sendAction json =
    sendActions [ json ]


port responseReceiver : (String -> msg) -> Sub msg


port connection : (String -> msg) -> Sub msg



-- UPDATE


type Msg
    = Navigate Route
    | Request Method (Maybe Params)
    | Recv String
    | PlayPause
    | QueryPlayers Time.Posix
    | ReceiveParamsResponse ParamsResponse
    | ReceiveResultResponse ResultResponse
    | ToggleRightSidebar
    | ToggleControlMenu
    | SendTextToKodi
    | ScanVideoLibrary
    | ScanMusicLibrary
    | VolumeSliderChange Float
    | ProgressSliderChange Float
    | SearchChanged String


songname : SongObj -> String
songname song =
    song.label


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Navigate route ->
            ( model
            , pushUrl model.key (Route.toString route)
            )

        Request method params ->
            case params of
                Nothing ->
                    ( model
                    , sendAction (request method Nothing)
                    )

                Just param ->
                    ( model
                    , sendAction (request method (Just { playerid = param.playerid, songid = Nothing, properties = param.properties }))
                    )

        Recv state ->
            case state of
                "Connected" ->
                    ( { model | connection = Connected }
                    , Cmd.none
                    )

                "Disconnected" ->
                    ( { model | connection = Disconnected }
                    , Cmd.none
                    )

                _ ->
                    ( model
                    , Cmd.none
                    )

        PlayPause ->
            ( model
            , sendAction """{ "jsonrpc": "2.0", "method": "Input.ExecuteAction", "params": { "action": "playpause" }, "id": 1 }"""
            )

        QueryPlayers _ ->
            ( model
            , sendAction """{"jsonrpc": "2.0", "method": "Player.GetActivePlayers", "id": 1}"""
            )

        ReceiveParamsResponse _ ->
            ( model
            , sendActions
                [ """{"jsonrpc": "2.0", "method": "Player.GetItem", "params": { "properties": ["title", "artist", "duration", "thumbnail", "genre"], "playerid": 0 }, "id": "AudioGetItem"}"""
                , """{"jsonrpc":"2.0","method":"Player.GetProperties","params":{"playerid":0,"properties":["percentage", "speed"]},"id":"0"}"""
                ]
            )

        ReceiveResultResponse result ->
            case result of
                --connected or disconnected
                ResultA _ ->
                    ( model
                    , Cmd.none
                    )

                ResultB playerObjects ->
                    ( { model | players = playerObjects }
                      --chain messages, once we get players, see what's playing
                    , sendActions
                        (List.map
                            (\player ->
                                case player of
                                    PlayerA playerid speed ->
                                        ""

                                    PlayerB playerid playertype ptype ->
                                        case ptype of
                                            Video ->
                                                """{"jsonrpc": "2.0", "method": "Player.GetItem", "params": { "properties": ["title", "album", "artist", "season", "episode", "duration", "showtitle", "tvshowid", "thumbnail", "file", "fanart", "streamdetails"], "playerid": """ ++ String.fromInt playerid ++ """ }, "id": "VideoGetItem"}"""

                                            Audio ->
                                                """{"jsonrpc": "2.0", "method": "Player.GetItem", "params": { "properties": ["title", "album", "artist", "duration", "genre", "thumbnail", "file", "fanart", "streamdetails"], "playerid": """ ++ String.fromInt playerid ++ """ }, "id": "AudioGetItem"}"""
                            )
                            model.players
                        )
                    )

                ResultC item ->
                    ( { model | currentlyPlaying = Just item }
                    , sendAction """{"jsonrpc":"2.0","method":"Player.GetProperties","params":{"playerid":0,"properties":["percentage", "speed"]},"id":"0"}"""
                    )

                ResultD songlist ->
                    let
                        genrelist =
                            unique (List.concatMap (\song -> song.genre) songlist)
                    in
                    ( { model | song_list = songlist, genre_list = genrelist }, Cmd.none )

                ResultE artistlist ->
                    ( { model | artist_list = artistlist }
                    , Cmd.none
                    )

                ResultF albumlist ->
                    ( { model | album_list = albumlist }
                    , Cmd.none
                    )

                ResultG movielist ->
                    ( { model | movie_list = movielist }
                    , Cmd.none
                    )

                ResultH percent playing ->
                    case playing of
                        0 ->
                            let
                                newSlider =
                                    SingleSlider.update percent model.progressSlider
                            in
                            ( { model | progressSlider = newSlider, playing = False }, Cmd.none )

                        1 ->
                            let
                                newSlider =
                                    SingleSlider.update percent model.progressSlider
                            in
                            ( { model | progressSlider = newSlider, playing = True }, Cmd.none )

                        _ ->
                            let
                                newSlider =
                                    SingleSlider.update percent model.progressSlider
                            in
                            ( { model | progressSlider = newSlider }, Cmd.none )

                ResultI sourcelist ->
                    ( { model | source_list = sourcelist }
                    , Cmd.none
                    )

        ToggleRightSidebar ->
            ( { model | rightSidebarExtended = not model.rightSidebarExtended }
            , Cmd.none
            )

        ToggleControlMenu ->
            ( { model | controlMenu = not model.controlMenu }
            , Cmd.none
            )

        SendTextToKodi ->
            ( model, Cmd.none )

        ScanVideoLibrary ->
            -- todo
            ( model, sendAction """""" )

        ScanMusicLibrary ->
            -- todo
            ( model, sendAction """""" )

        VolumeSliderChange newValue ->
            let
                newSlider =
                    SingleSlider.update newValue model.volumeSlider
            in
            ( { model | volumeSlider = newSlider }, sendAction ("""{"jsonrpc":"2.0","method":"Application.SetVolume","id":1,"params":{"volume":""" ++ String.fromFloat newValue ++ """}}""") )

        ProgressSliderChange newValue ->
            let
                newSlider =
                    SingleSlider.update newValue model.progressSlider
            in
            ( { model | progressSlider = newSlider }, sendAction ("""{"jsonrpc":"2.0", "method":"Player.Seek", "id":1, "params": { "playerid":0, "value":""" ++ String.fromFloat newValue ++ """}}""") )

        SearchChanged searchString ->
            ( { model | searchString = searchString }, Cmd.none )



-- SUBSCRIPTIONS


decodeWS message =
    case D.decodeString paramsResponseDecoder message of
        Ok paramsMessage ->
            ReceiveParamsResponse paramsMessage

        Err _ ->
            case D.decodeString resultResponseDecoder message of
                Ok resultMessage ->
                    ReceiveResultResponse resultMessage

                Err _ ->
                    Recv message


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.batch
        [ responseReceiver decodeWS
        , connection decodeWS
        , Time.every 1000 QueryPlayers
        ]



-- VIEW


view :
    { page : Document msg, toMsg : Msg -> msg }
    -> Model
    -> { body : Document msg, header : Element msg, playerBar : Element msg, rightSidebar : Element msg }
view { page, toMsg } model =
    Components.Frame.layout
        { page = page
        , controlMenu =
            { controlMenu = model.controlMenu
            , controlMenuMsg = toMsg ToggleControlMenu
            , sendTextToKodiMsg = toMsg SendTextToKodi
            , scanMusicLibraryMsg = toMsg ScanMusicLibrary
            , scanVideoLibraryMsg = toMsg ScanMusicLibrary
            }
        , playerControl =
            { playPauseMsg = toMsg PlayPause
            , skipMsg = toMsg (Request Player_PlayPause Nothing) -- todo
            , reverseMsg = toMsg (Request Player_PlayPause (Just (Params (Just 0) Nothing Nothing))) -- todo
            , playing = model.playing
            }
        , currentlyPlaying =
            { currentlyPlaying = model.currentlyPlaying
            , progressSlider = Element.map toMsg (slider model.progressSlider)
            }
        , volumeAndControls =
            { muteMsg = toMsg (Request Application_SetMute (Just (Params (Just 0) Nothing Nothing)))
            , repeatMsg = toMsg (Request Player_SetRepeat (Just (Params (Just 0) Nothing Nothing)))
            , shuffleMsg = toMsg (Request Player_SetShuffle (Just (Params (Just 0) Nothing Nothing)))
            , volumeSlider = Element.map toMsg (slider model.volumeSlider)
            }
        , rightSidebarExtended = model.rightSidebarExtended
        , rightSidebarMsg = toMsg ToggleRightSidebar
        , connection = model.connection
        , windowHeight = model.windowHeight
        , searchChanged = toMsg (SearchChanged "")
        }


slider : SingleSlider msg -> Element msg
slider singleSliderMsg =
    SingleSlider.view singleSliderMsg |> Element.html
