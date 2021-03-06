module Page.Settings exposing (FoodPreference, Model, Msg(..), init, subscriptions, toSession, update, view)

import Array
import Helper exposing (decodeProfile, endPoint, informHttpError, prepareAuthHeader)
import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Html.Events.Extra exposing (targetValueIntParse)
import Http
import Json.Decode as Decode
import Route
import Session exposing (Session, logout)
import Http
import Helper exposing (prepareAuthHeader, endPoint, informHttpError, decodeProfile)
import Json.Decode as Decode


init : Session -> ( Model, Cmd Msg )
init session =
    let
        

        model =
            { session = session
            , user =
            { email = ""
            , profileName = ""            
            }
            , problem = []
            , preferences = {
                likes = ""
                , prIn = 0
                , carbIn = 0
                , vitaIn = 0
            }
            }

        cmd =
            case Session.cred session of
                Just cred ->
                    Cmd.batch
                        [getAccountInfo session, getFoodPreferences session ]

                Nothing ->
                    Route.replaceUrl (Session.navKey session) Route.Login
    in
    ( model, cmd )


type alias Model =
    { session : Session
    , problem : List Problem
    , user : User
    , preferences : FoodPreference 
    } 


type Problem
    = ServerError String


type alias User =
    { email : String
    , profileName : String
    }

-- UPDATE


type Msg
    = GotAccountInfo (Result Http.Error Account)
    | GotSettingsInfo (Result Http.Error FoodPreference)
    | SubmitAccount
    | SetField Field String
    | ClickedLogout
    | Increase Ty
    | Decrease Ty


type Ty = 
    Carbohydrate
    | Fat
    | Protein

updateIntake : Ty -> FoodPreference -> FoodPreference
updateIntake ty fp =
    case ty of
        Carbohydrate ->
            {fp | carbIn = fp.carbIn + 1}
    
        Fat ->
            {fp | vitaIn = fp.vitaIn + 1}
        
        Protein ->
            {fp | prIn = fp.prIn + 1}
            

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        Increase ty ->
            let
                newModel = 
                    case ty of
                        Carbohydrate ->
                            {model | preferences = updateIntake ty model.preferences}
                        
                        Fat ->
                            {model | preferences = updateIntake ty model.preferences}

                        Protein ->
                            {model | preferences = updateIntake ty model.preferences}
                            
            in
            (newModel, Cmd.none)

        Decrease ty ->
            let
                newModel = 
                    case ty of
                        Carbohydrate ->
                            {model | preferences = updateIntake ty model.preferences}
                        
                        Fat ->
                            {model | preferences = updateIntake ty model.preferences}

                        Protein ->
                            {model | preferences = updateIntake ty model.preferences}
                            
            in
            (newModel, Cmd.none)

        GotAccountInfo resp ->
            let
                newModel =
                    case resp of
                        Ok a ->
                            updateForm (\f -> { f | profileName = a.username, email = a.email }) model

                        Err e ->
                            { model | problem = [ ServerError <| informHttpError e ] }
            in
            ( newModel, Cmd.none )

        GotSettingsInfo resp ->
            let
                newModel =
                    case resp of
                        Ok a ->
                            { model | preferences = a }
                            
                        Err e ->
                            { model | problem = [ ServerError <| informHttpError e ] }
            in
            ( newModel, Cmd.none )

        SubmitAccount ->
            ( model, Cmd.none )

        SetField field val ->
            ( model |> setField field val
            , Cmd.none
            )

        ClickedLogout ->
            ( model, Cmd.batch [ Session.logout, Route.loadPage Route.Login ] )



-- record update helpers

updateForm : (User -> User) -> Model -> Model
updateForm transform model =
    { model | user = transform model.user }
 

setField : Field -> String -> Model -> Model
setField field val model =
    case field of
        Email ->
            updateForm (\user -> { user | email = val }) model

        ProfileName ->
            updateForm (\user -> { user | profileName = val }) model
        
-- VIEW


view : Model -> { title : String, content : Html Msg }
view model =
    { title = "Settings"
    , content = viewSettings model
    }


viewSettings : Model -> Html Msg
viewSettings model =
    div []
        [ viewNavbar model
        , br [] []
        , br [] []
        , div [ class "settings-container" ]
            [ ul [] (List.map (\str -> viewError str) model.problem)
            , viewAccountInfo model
            , viewPersonalSettings model
            ]
        ]


viewError : Problem -> Html msg
viewError (ServerError str) =
    div [ class "alert"]
        [ text str ]


viewAccountInfo : Model -> Html Msg
viewAccountInfo model =
    div [ class "task-form settings-form" ]
        [ text " Account Info"
        , inputField ProfileName model model.user.profileName "Full Name" "text"
        , inputField Email model model.user.email "Email" "text"
        ]


viewPersonalSettings : Model -> Html Msg
viewPersonalSettings model =
    let
        txt = 
            if model.preferences.likes == "vegan" then
                veganMojo
            else if model.preferences.likes == "vegetarian" then
                vegetarianMojo
            else
                theRestMojo
    in
    div [ class "" ]
        [ p [] [text"Food Preferences"]
        , hr [] []
        , label [] [
            text txt
            , input [
            type_ "text"
            , value model.preferences.likes 
            , disabled True
            ] []
        ]
        , p [] [text "Protein"]
        , button [onClick <| Increase Protein] [text "Increase protein uptake"]
        , button [onClick <| Decrease Protein] [text "Decrease protein uptake"]
        , hr [] []
        , p [] [text "Carbohydrates"]
        , button [onClick <| Increase Carbohydrate] [text "Increase carb uptake"]
        , button  [onClick <| Decrease Carbohydrate] [text "Decrease carb uptake"]
        , hr [] []
        , p [] [text "Fat"]
        , button [onClick <| Increase Fat] [text "Increase fat uptake"]
        , button [onClick <| Decrease Fat] [text "Decrease fat uptake"]  
        , hr [] []
        , button [] [text "Submit"]
        ]


viewNavbar : Model -> Html Msg
viewNavbar model =
    nav [class "navbar navbar-fixed"]
        [div [class "nav-header"]
            [ a [ class "navbar-toggle"] 
                [span [class "fa fa-bars"] []
                ]
            , a [class "header", href "/"] [text "EatRight"]
            ]
        , div [class "nav", id "nav"]
            [ ul [id "nav-collapse"] [
                li [] [a [href "/"] [text "Home"]]
                , li [] [a [onClick ClickedLogout] [text "Logout"]]
            ]
            ]
        ]


type Field
    = Email
    | ProfileName


inputField : Field -> Model -> String -> String -> String -> Html Msg
inputField field {user} plceholder lbel taype =
    let
        val =
            case field of
                Email -> 
                    user.email
                
                ProfileName ->
                    user.profileName
                
    in
    div [ class ""]
        [ span [] [ label [ class "task-form-input-title" ] [ text lbel ] ]
        , input
            [ class "task-form-input"
            , type_ taype
            , placeholder plceholder
            , onInput <| SetField field
            , value val
            ]
            []
        ]


toSession : Model -> Session
toSession model =
    model.session


getInt : String -> Int
getInt str =
    String.toInt str |> Maybe.withDefault 0


type alias Account =
    { email : String
    , id : String
    , username : String
    }


type alias FoodPreference =
    { likes : String
    , prIn: Float
    , carbIn : Float
    , vitaIn : Float
    }



-- Subscriptions


subscriptions : Model -> Sub Msg
subscriptions _ =
    Sub.none



-- http


getAccountInfo : Session -> Cmd Msg
getAccountInfo session =
    Http.request
        { headers = [ prepareAuthHeader session ]
        , url = endPoint [ "status" ]
        , body = Http.emptyBody
        , method = "GET"
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson GotAccountInfo decodeProfile
        }


getFoodPreferences : Session -> Cmd Msg
getFoodPreferences session = 
    Http.request
        { headers = [ prepareAuthHeader session]
        , url = endPoint ["settings"]
        , body = Http.emptyBody
        , method = "GET"
        , timeout = Nothing
        , tracker = Nothing
        , expect = Http.expectJson GotSettingsInfo decodeFoodPreference
        }

decodeFoodPreference : Decode.Decoder FoodPreference
decodeFoodPreference = 
    Decode.map4 FoodPreference
        (Decode.field "preference" Decode.string)
        (Decode.field "protein" Decode.float)
        (Decode.field "carb" Decode.float)
        (Decode.field "fat" Decode.float)


veganMojo = 
    """
    Veganism is the practice of abstaining from the use of animal products, 
    particularly in diet, and an associated philosophy that rejects the commodity status of animals. 
    A follower of the diet or the philosophy is known as a vegan.
    """

vegetarianMojo =
    """Vegetarianism is the practice of abstaining from the consumption of meat, 
    and may also include abstention from by-products of animals processed for food. 
    Vegetarianism may be adopted for various reasons. 
    Many people object to eating meat out of respect for sentient life
    """

theRestMojo =
    """You are so strong you can do anything that's why you eat anything. We love you.
    """
