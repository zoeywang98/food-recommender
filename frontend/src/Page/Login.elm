module Page.Login exposing (Model, Msg, init, toSession, view, update, subscriptions) 

import Session exposing (Session)
import Html exposing (..)
import Html.Events exposing(onClick, onInput)
import Html.Attributes exposing (..)
import Route exposing (Route)
import Browser.Navigation as Navigation exposing (load)
import Http
import User exposing (Profile)
import Json.Decode exposing (field, Decoder, string, map3, map2)
import Json.Encode as Encode

type alias Model = 
    { session : Session
    , form : Form
    , problems : List Problem
    }

type Problem
    = InvalidEntry ValidatedField String
    | ServerError String


-- VIEW 
view : Model -> { title : String, content : Html Msg}
view model = 
    { title = "Eat Right - Login"
    , content = (loginView model)
    }

init : Session -> (Model, Cmd Msg)
init session =
    ({ session = session
     , problems  = [] 
     , form = 
           { email = ""
           , password = ""
           }
    }
    , Cmd.none
    )


type alias Form =
    { email : String
    , password : String
    }

loginView : Model -> Html Msg
loginView model = 
    div [ class "login-page"]
        [ ul []
          (List.map (\str -> viewServerError str) model.problems)
        ,(loginForm model) 
        ]


loginForm : Model -> Html Msg
loginForm model = 
    div [ class "vert-form" ]
        [ viewInput model Email "Email" "text" "johndoe@example.com"
        , viewInput model Password "Password" "password" "*******"
        , div [ class "login-button-row"]
              [ button [ class "blue-button button", onClick SubmittedDetails ] [ text "LOGIN" ] ]
        ]


viewServerError : Problem -> Html Msg
viewServerError problem =  
     case problem of 
        ServerError str ->
            text str
        _ ->
            text ""

viewProblem : Model -> ValidatedField -> Problem -> Html msg
viewProblem model formfield problem =  
        let
            errorMsg =
                case problem of
                    InvalidEntry f str ->
                        if f == formfield then
                            str
 
                        else
                            ""
 
                    ServerError _ ->
                        ""
        in
        if String.length errorMsg > 1 then
            p [class "validation-problem"] [ text errorMsg ]
 
        else
            text ""


setErrors : List Problem -> Model -> Model
setErrors problems model =
    { model | problems = problems }  

setField : ValidatedField-> String -> Model-> Model
setField field value model =
    case field of
        Email ->
            updateForm (\form -> { form | email = value }) model
       
        Password ->
            updateForm (\form -> { form | password = value }) model
 

viewInput : Model -> ValidatedField -> String -> String -> String -> Html Msg
viewInput model formField labelName inputType inputName =
    let
        what =
            case formField of 
                    Email ->
                        model.form.email
 
                    Password ->
                        model.form.password
                   
        lis =
            List.map (\err -> viewProblem model formField err) model.problems
 
    in
    label
        [ class "form-label" ]
        [ text labelName
        , input
            [ type_ inputType
            , placeholder inputName
            , onInput <| SetField formField
            , value what
            ]
            []
 
            , ul [] lis
    ]

type Msg 
    = SubmittedDetails
    | SetField ValidatedField String
    | GotResponse (Result Http.Error Response)
    | GotSession Session


update : Msg -> Model -> (Model, Cmd Msg)
update msg model = 
    let 
        problemList =
            validate model.form
    in
    case msg of 
        SubmittedDetails ->
            case problemList of 
                [] ->
                    -- send data to the server 
                    -- receive server response 
                    -- trigger command to handle or consume response
                    ({ model | problems = [] }
                    , login model
                    )
                
                problems ->
                    ( { model | problems = problems }
                    , Cmd.none
                    )

        SetField field value->
            ( model
                |> setField field value
                |> setErrors problemList
            , Cmd.none)  
        
        GotResponse resp ->
            case resp of 
                Ok successData ->
                    (model
                    , Cmd.batch [Session.login successData, Navigation.load "/home"]
                    )
                
                Err err ->
                    case err of 
                        Http.BadStatus _ ->
                            ({model | problems = [ServerError "Oh the request failed. Something must've gone wrong. Try again."]}
                            , Cmd.none
                            )

                        Http.Timeout ->
                            ({model | problems = [ServerError "Server took too long to respond."]}
                            , Cmd.none
                            )
                        
                        Http.NetworkError ->
                            ({model | problems = [ServerError "Network error. Please check your wifi."]}
                            , Cmd.none
                            )
                        
                        Http.BadBody _ ->
                            ({model | problems = [ServerError "Oooh something went wrong. Try again!"]}
                            , Cmd.none
                            )
                        
                        Http.BadUrl _ ->
                            ({model | problems = [ServerError "Invalid url."]}
                            , Cmd.none
                            )
                        

        GotSession session ->
            ( { model | session = session }
            , Navigation.load "/home" 
            )


-- tiny helper function to update the form in the session 
updateForm : (Form -> Form) -> Model -> Model
updateForm transform model = 
    { model | form = transform model.form }

-- Subscriptions 
subscriptions : Model -> Sub Msg
subscriptions model =
    Session.changes GotSession (Session.navKey model.session)



-- Handle the Form 
type ValidatedField 
    = Email 
    | Password 

-- To ensure we only trim the form when the user is done 
type TrimmedForm 
    = Trimmed Form


fieldsToValidate : List ValidatedField 
fieldsToValidate =
    [ Email
    , Password
    ]


-- trim and validate form 
validate : Form -> List Problem
validate form = 
    let 
        trimmedForm =
            trimFields form 
    in 
        case List.concatMap(validateField trimmedForm) fieldsToValidate of
            [] ->
                [] 
            problems ->
                problems


-- validateField
validateField : TrimmedForm -> ValidatedField -> List Problem
validateField (Trimmed form) field = 
    List.map (InvalidEntry field) <|
        case field of 
            Email ->
                if String.isEmpty form.email then 
                    [ "email can't be blank." ]
                
                else
                    []

            Password ->
                if String.isEmpty form.password  then 
                    ["password can't be blank." ]

                else if String.length form.password < 8 then
                    [ "password should be at least 8 characters long." ]
                   
                else 
                    []

-- trimFields on demand 
trimFields : Form -> TrimmedForm 
trimFields form =
    Trimmed 
        { email = String.trim form.email
        , password = String.trim form.password 
        }

                    

-- Exported Session Builder 
toSession : Model -> Session
toSession model =  
    model.session

-- http 

login : Model -> Cmd Msg
login model =    
    Http.post
      { url = ""
      , body = Http.jsonBody (encodeLogin model )
      , expect = Http.expectJson GotResponse decodeResponse
      }

type alias Response =
    { token : String
    , profile : Profile
    }

decodeResponse : Decoder Response
decodeResponse = 
    map2 Response
        (field "token" string)
        (field "profile" decodeProfile)

decodeProfile : Decoder Profile
decodeProfile = 
    map3 Profile
        (field "fullname" string)
        (field "email" string)
        (field "id" string)

encodeLogin : Model -> Encode.Value
encodeLogin {form} = 
    Encode.object
        [ ( "email", Encode.string form.email )
        , ( "password", Encode.string form.password )
        ]