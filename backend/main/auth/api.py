from flask import Blueprint

from flask import request, make_response, jsonify
from flask.views import MethodView

from main import bcrypt, db
from main.model.model import User, BadToken, Settings

from main.alg.geneticAlgo.genetic_algorithm import *


class UserAPI(MethodView):
    """
    User Resource
    """
    def get(self):
        # get the auth token
        auth_header = request.headers.get('Authorization')
        if auth_header:
            try:
                auth_token = auth_header.split(" ")[0]
            except IndexError:
                responseObject = {
                    'status': 'fail',
                    'message': 'Bearer token malformed.'
                }
                return make_response(jsonify(responseObject)), 401
        else:
            auth_token = ''
        if auth_token:
            resp = User.decode_auth_token(auth_token)
            if isinstance(resp, str):
                user = User.query.filter_by(id=resp).first()
                responseObject = {
                        'id': user.id,
                        'username': user.fullname,
                        'email': user.email
                }
                return make_response(jsonify(responseObject)), 200
            responseObject = {
                'status': 'fail',
                'message': resp
            }
            return make_response(jsonify(responseObject)), 401
        else:
            responseObject = {
                'status': 'fail',
                'message': 'Provide a valid auth token.'
            }
            return make_response(jsonify(responseObject)), 401

class RegisterAPI(MethodView):
    """
    User Registration Resource
    """
    def post(self):
        # get the post data
        post_data = request.get_json()
        # check if user already exists
        user = User.query.filter_by(email=post_data['email']).first()
        if not user:
            try:
                user = User(
                    fullname=post_data['fullname'],
                    email=post_data['email'],
                    age=post_data['age'],
                    password=post_data['password'],
                    gender=post_data['gender']
                )

                # insert the user
                db.session.add(user)
                db.session.commit()
                # generate the auth token
                auth_token = user.encode_auth_token(user.id)
                settings = Settings(user.id, post_data['preference'], 19.0, 5.0, 2.0)
                # store user default settings
                db.session.add(settings)
                db.session.commit()

                responseObject = {
                    'token': auth_token.decode(),
                    'profile': {
                        'id': user.id,
                        'username': user.fullname,
                        'email': user.email
                    }
                }
                return make_response(jsonify(responseObject)), 201
                
            except Exception as e:
                print(e)
                responseObject = {
                    'status': 'fail',
                    'message': f'Some error occurred. Please try again. {e}'
                }
                return make_response(jsonify(responseObject)), 500
        else:
            responseObject = {
                'status': 'fail',
                'message': 'User already exists. Please Log in.',
            }
            return make_response(jsonify(responseObject)), 202

class LoginAPI(MethodView):
    """
    User Login Resource
    """
    def post(self):
        # get the post data
        post_data = request.get_json()
        try:
            # fetch the user data
            user = User.query.filter_by(
                email=post_data['email']
            ).first()
            if user and bcrypt.check_password_hash(
                user.password, post_data['password']
            ):
                auth_token = user.encode_auth_token(user.id)
                if auth_token:
                    responseObject = {
                        'token': auth_token.decode(),
                        'profile': {
                            'id': user.id,
                            'username': user.fullname,
                            'email': user.email
                            }
                    }
                    return make_response(jsonify(responseObject)), 200
            else:
                responseObject = {
                    'status': 'fail',
                    'message': 'User does not exist.'
                }
                return make_response(jsonify(responseObject)), 404
        except Exception as e:
            print(e)
            responseObject = {
                'status': 'fail',
                'message': 'Try again'
            }
            return make_response(jsonify(responseObject)), 500

class LogoutAPI(MethodView):
    """
    Logout Resource
    """
    def post(self):
        # get auth token
        auth_header = request.headers.get('Authorization')
        if auth_header:
            auth_token = auth_header.split(" ")[0]
        else:
            auth_token = ''
        if auth_token:
            resp = User.decode_auth_token(auth_token)
            if not isinstance(resp, str):
                # mark the token as blacklisted
                blacklist_token = BlacklistToken(token=auth_token)
                try:
                    # insert the token
                    db.session.add(blacklist_token)
                    db.session.commit()
                    responseObject = {
                        'status': 'success',
                        'message': 'Successfully logged out.'
                    }
                    return make_response(jsonify(responseObject)), 200
                except Exception as e:
                    responseObject = {
                        'status': 'fail',
                        'message': e
                    }
                    return make_response(jsonify(responseObject)), 200
            else:
                responseObject = {
                    'status': 'fail',
                    'message': resp
                }
                return make_response(jsonify(responseObject)), 401
        else:
            responseObject = {
                'status': 'fail',
                'message': 'Provide a valid auth token.'
            }
            return make_response(jsonify(responseObject)), 403

class RecommendAPI(MethodView):
    """
    Recommend Resource
    """
    def get(self):
        # get auth token
        auth_header = request.headers.get('Authorization')
        if auth_header:
            try:
                auth_token = auth_header.split(" ")[0]
            except IndexError:
                responseObject = {
                    'status': 'fail',
                    'message': 'Bearer token malformed.'
                }
                return make_response(jsonify(responseObject)), 401
        else:
            auth_token = ''
        if auth_token:
            resp = User.decode_auth_token(auth_token)
            if isinstance(resp, str):

                settns = Settings.query.filter_by(id=resp).first()
                ## do recommendation here
                if settns.preference == 'vegan':
                    menuData = setMenuData('vegan.json')
                elif settns.preference == 'mixed_food':
                    menuData = setMenuData('mixed_food.json')
                elif settns.preference == 'vegetarian':
                    menuData = setMenuData('vegetarian.json')
                else:
                    menuData = setMenuData('mixed_food.json')
                    
                # cuisineScore = {settns.preference: 0.90}

                # temp = createInitialPopu(1, 10, menuData)
                # temp1 = rankDishes(temp, cuisineScore, 2, menuData)
                # matePool = selection(temp1,2)
                # newGen = crossover(matePool,temp,5)
                # newGenAfterMutation = mutatePopulation(newGen, 10, 0.67)
                # import random
                # rec = newGenAfterMutation[random.randrange(0, len(newGenAfterMutation))]

                start_point = int(settns.protein_intake + settns.fat_intake + settns.carb_intake)

                rec = random.randrange(start_point, len(menuData))
                food = menuData[rec]
                    
                responseObject = {
                        'food': food["Food Name"],
                        'protein':food["Protein (g)"],
                        'carb':food["Carbohydrate (g)"],
                        'fat':food["Fat (g)"],
                        'energy':food["Energy (kJ)"],
                        'calories':food["Energy (kCal)"],
                        "water": food["Water (g)"],
                        "fibre": food["Fibre (g)"]
                }
                
                return make_response(jsonify(responseObject)), 200
            responseObject = {
                'status': 'fail',
                'message': resp
            }
            return make_response(jsonify(responseObject)), 401
        else:
            responseObject = {
                'status': 'fail',
                'message': 'Provide a valid auth token.'
            }
            return make_response(jsonify(responseObject)), 401


class SettingsAPI(MethodView):
    """
    Settings API
    """
    def get(self):
        # get auth token
        auth_header = request.headers.get('Authorization')
        if auth_header:
            try:
                auth_token = auth_header.split(" ")[0]
            except IndexError:
                responseObject = {
                    'status': 'fail',
                    'message': 'Bearer token malformed.'
                }
                return make_response(jsonify(responseObject)), 401
        else:
            auth_token = ''
        if auth_token:
            resp = User.decode_auth_token(auth_token)
            if isinstance(resp, str):

                settns = Settings.query.filter_by(id=resp).first()

                responseObject = {
                        'preference': settns.preference,
                        'protein': settns.protein_intake,
                        'carb': settns.carb_intake,
                        'fat': settns.fat_intake
                }
                return make_response(jsonify(responseObject)), 200
            
            responseObject = {
                'status': 'fail',
                'message': 'Provide a valid auth token.'
            }

            return make_response(jsonify(responseObject)), 401
        else:
            responseObject = {
                'status': 'fail',
                'message': 'Provide a valid auth token.'
            }
            return make_response(jsonify(responseObject)), 401


auth_blueprint = Blueprint('auth', __name__)

# define the API resources
registration_view = RegisterAPI.as_view('register_api')
user_view = UserAPI.as_view('user_api')
login_view = LoginAPI.as_view('login_api')
logout_view = LogoutAPI.as_view('logout_api')
recommend_view = RecommendAPI.as_view('recommend_api')
settings_view = SettingsAPI.as_view("settings_api")

# add Rules for API Endpoints
auth_blueprint.add_url_rule(
    '/auth/register',
    view_func=registration_view,
    methods=['POST']
)

auth_blueprint.add_url_rule(
    '/status',
    view_func=user_view,
    methods=['GET']
)

auth_blueprint.add_url_rule(
    '/auth/login',
    view_func=login_view,
    methods=['POST']
)

auth_blueprint.add_url_rule(
    '/auth/logout',
    view_func=logout_view,
    methods=['POST']
)

auth_blueprint.add_url_rule(
    '/recommend',
    view_func=recommend_view,
    methods=['GET']
)

auth_blueprint.add_url_rule(
    '/settings',
    view_func=settings_view,
    methods=["GET"]
)
