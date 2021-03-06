module Page.SpaceUsers exposing (Model, Msg(..), consumeEvent, init, setup, teardown, title, update, view)

import Avatar
import Browser.Navigation as Nav
import Connection exposing (Connection)
import Device exposing (Device)
import Event exposing (Event)
import Globals exposing (Globals)
import Group exposing (Group)
import Html exposing (..)
import Html.Attributes exposing (..)
import Icons
import Id exposing (Id)
import Layout.SpaceDesktop
import Layout.SpaceMobile
import ListHelpers exposing (insertUniqueBy, removeBy)
import PageError exposing (PageError)
import Pagination
import Query.SpaceUsersInit as SpaceUsersInit
import Repo exposing (Repo)
import Route exposing (Route)
import Route.Posts
import Route.SpaceUser
import Route.SpaceUsers exposing (Params)
import Scroll
import Session exposing (Session)
import Space exposing (Space)
import SpaceUser exposing (SpaceUser)
import Task exposing (Task)
import Tuple
import View.Helpers exposing (viewIf)



-- MODEL


type alias Model =
    { params : Params
    , viewerId : Id
    , spaceId : Id

    -- MOBILE
    , showNav : Bool
    , showSidebar : Bool
    }


type alias IndexedUser =
    ( Int, SpaceUser )


type alias Data =
    { viewer : SpaceUser
    , space : Space
    }


resolveData : Repo -> Model -> Maybe Data
resolveData repo model =
    Maybe.map2 Data
        (Repo.getSpaceUser model.viewerId repo)
        (Repo.getSpace model.spaceId repo)



-- PAGE ATTRIBUTES


title : String
title =
    "People"



-- LIFECYCLE


init : Params -> Globals -> Task PageError ( Globals, Model )
init params globals =
    let
        maybeUserId =
            Session.getUserId globals.session

        maybeSpaceId =
            globals.repo
                |> Repo.getSpaceBySlug (Route.SpaceUsers.getSpaceSlug params)
                |> Maybe.andThen (Just << Space.id)

        maybeViewerId =
            case ( maybeSpaceId, maybeUserId ) of
                ( Just spaceId, Just userId ) ->
                    Repo.getSpaceUserByUserId spaceId userId globals.repo
                        |> Maybe.andThen (Just << SpaceUser.id)

                _ ->
                    Nothing
    in
    case ( maybeViewerId, maybeSpaceId ) of
        ( Just viewerId, Just spaceId ) ->
            let
                model =
                    Model
                        params
                        viewerId
                        spaceId
                        False
                        False
            in
            Task.succeed ( globals, model )

        _ ->
            Task.fail PageError.NotFound


setup : Model -> Cmd Msg
setup model =
    Scroll.toDocumentTop NoOp


teardown : Model -> Cmd Msg
teardown model =
    Cmd.none



-- UPDATE


type Msg
    = NoOp
    | ToggleKeyboardCommands
    | ToggleNotifications
    | InternalLinkClicked String
      -- MOBILE
    | NavToggled
    | SidebarToggled
    | ScrollTopClicked


update : Msg -> Globals -> Model -> ( ( Model, Cmd Msg ), Globals )
update msg globals model =
    case msg of
        NoOp ->
            ( ( model, Cmd.none ), globals )

        ToggleKeyboardCommands ->
            ( ( model, Cmd.none ), { globals | showKeyboardCommands = not globals.showKeyboardCommands } )

        ToggleNotifications ->
            ( ( model, Cmd.none ), { globals | showNotifications = not globals.showNotifications } )

        InternalLinkClicked pathname ->
            ( ( model, Nav.pushUrl globals.navKey pathname ), globals )

        NavToggled ->
            ( ( { model | showNav = not model.showNav }, Cmd.none ), globals )

        SidebarToggled ->
            ( ( { model | showSidebar = not model.showSidebar }, Cmd.none ), globals )

        ScrollTopClicked ->
            ( ( model, Scroll.toDocumentTop NoOp ), globals )



-- EVENTS


consumeEvent : Event -> Model -> ( Model, Cmd Msg )
consumeEvent event model =
    ( model, Cmd.none )



-- VIEW


view : Globals -> Model -> Html Msg
view globals model =
    case resolveData globals.repo model of
        Just data ->
            resolvedView globals model data

        Nothing ->
            text "Something went wrong."


resolvedView : Globals -> Model -> Data -> Html Msg
resolvedView globals model data =
    case globals.device of
        Device.Desktop ->
            resolvedDesktopView globals model data

        Device.Mobile ->
            resolvedMobileView globals model data



-- DESKTOP


resolvedDesktopView : Globals -> Model -> Data -> Html Msg
resolvedDesktopView globals model data =
    let
        config =
            { globals = globals
            , space = data.space
            , spaceUser = data.viewer
            , onNoOp = NoOp
            , onToggleKeyboardCommands = ToggleKeyboardCommands
            , onPageClicked = NoOp
            }

        spaceUsers =
            globals.repo
                |> Repo.getSpaceUsersBySpaceId model.spaceId
                |> List.filter (\su -> SpaceUser.state su == SpaceUser.Active)
                |> List.sortBy SpaceUser.lastName
    in
    Layout.SpaceDesktop.layout config
        [ div [ class "mx-auto max-w-sm leading-normal p-8" ]
            [ div [ class "flex items-center mb-6 pb-5 border-b" ]
                [ h1 [ class "flex-1 mr-4 font-bold tracking-semi-tight text-3xl" ] [ text "People" ]
                , div [ class "flex-0 flex-no-shrink" ]
                    [ a
                        [ Route.href (Route.InviteUsers (Route.SpaceUsers.getSpaceSlug model.params))
                        , class "btn btn-blue btn-md no-underline"
                        ]
                        [ text "Invite people" ]
                    ]
                ]

            -- , div [ class "pb-6" ]
            --     [ label [ class "flex items-center p-4 w-full rounded bg-grey-light" ]
            --         [ div [ class "flex-0 flex-no-shrink pr-3" ] [ Icons.search ]
            --         , input [ id "search-input", type_ "text", class "flex-1 bg-transparent no-outline", placeholder "Type to search" ] []
            --         ]
            --     ]
            , usersView model data spaceUsers
            ]
        ]



-- MOBILE


resolvedMobileView : Globals -> Model -> Data -> Html Msg
resolvedMobileView globals model data =
    let
        config =
            { globals = globals
            , space = data.space
            , spaceUser = data.viewer
            , title = "People"
            , showNav = model.showNav
            , onNavToggled = NavToggled
            , onSidebarToggled = SidebarToggled
            , onScrollTopClicked = ScrollTopClicked
            , onNoOp = NoOp
            , leftControl = Layout.SpaceMobile.ShowNav
            , rightControl =
                Layout.SpaceMobile.Custom <|
                    a
                        [ class "btn btn-blue btn-md no-underline"
                        , Route.href (Route.InviteUsers (Route.SpaceUsers.getSpaceSlug model.params))
                        ]
                        [ text "Invite" ]
            }

        spaceUsers =
            globals.repo
                |> Repo.getSpaceUsersBySpaceId model.spaceId
                |> List.filter (\su -> SpaceUser.state su == SpaceUser.Active)
                |> List.sortBy SpaceUser.lastName
    in
    Layout.SpaceMobile.layout config
        [ div [ class "p-3" ]
            [ usersView model data spaceUsers
            ]
        ]



-- SHARED


usersView : Model -> Data -> List SpaceUser -> Html Msg
usersView model data spaceUsers =
    div [ class "leading-semi-loose" ]
        [ div [] <| List.map (userView model data) spaceUsers
        ]


userView : Model -> Data -> SpaceUser -> Html Msg
userView model data spaceUser =
    let
        params =
            model.params

        spaceSlug =
            Route.SpaceUsers.getSpaceSlug params

        viewParams =
            Route.SpaceUser.init spaceSlug (SpaceUser.handle spaceUser)

        feedParams =
            if SpaceUser.id data.viewer == SpaceUser.id spaceUser then
                Route.Posts.init spaceSlug
                    |> Route.Posts.setRecipients (Just [ SpaceUser.handle data.viewer ])
                    |> Route.Posts.clearFilters

            else
                Route.Posts.init spaceSlug
                    |> Route.Posts.setRecipients (Just [ SpaceUser.handle data.viewer, SpaceUser.handle spaceUser ])
                    |> Route.Posts.clearFilters
    in
    div [ class "pb-1 flex items-center font-normal font-sans text-lg" ]
        [ div [ class "mr-3" ] [ SpaceUser.avatar Avatar.Small spaceUser ]
        , a
            [ Route.href (Route.Posts feedParams)
            , class "block flex-grow no-underline text-dusty-blue-darker"
            ]
            [ text (SpaceUser.displayName spaceUser) ]
        , a
            [ Route.href (Route.SpaceUser viewParams)
            , class "ml-2 flex items-center justify-center w-9 h-9 rounded-full bg-transparent hover:bg-grey transition-bg"
            ]
            [ Icons.settings ]
        ]
