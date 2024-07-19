from flask import Flask, request, jsonify
from flask_sqlalchemy import SQLAlchemy
from datetime import datetime, timedelta
import base64
import io
from PIL import Image
import numpy as np
import os
from dotenv import load_dotenv
from openai import OpenAI
from werkzeug.security import generate_password_hash, check_password_hash
from flask_jwt_extended import JWTManager, jwt_required, create_access_token, get_jwt_identity

load_dotenv()

app = Flask(__name__)
app.config['SQLALCHEMY_DATABASE_URI'] = os.getenv('DATABASE_URL', 'sqlite:///nutrilens.db')
app.config['JWT_SECRET_KEY'] = os.getenv('JWT_SECRET_KEY')
db = SQLAlchemy(app)
jwt = JWTManager(app)

client = OpenAI(api_key=os.getenv('OPENAI_API_KEY'))

# Models
class User(db.Model):
    id = db.Column(db.Integer, primary_key=True)
    username = db.Column(db.String(80), unique=True, nullable=False)
    password_hash = db.Column(db.String(128))
    daily_calorie_goal = db.Column(db.Integer, default=2000)

class FoodLog(db.Model):
    id = db.Column(db.String(36), primary_key=True)
    user_id = db.Column(db.Integer, db.ForeignKey('user.id'), nullable=False)
    food_name = db.Column(db.String(120), nullable=False)
    calories = db.Column(db.Integer, nullable=False)
    date = db.Column(db.DateTime, nullable=False)

# Authentication Routes
@app.route('/register', methods=['POST'])
def register():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    if User.query.filter_by(username=username).first():
        return jsonify({"message": "Username already exists"}), 400

    new_user = User(username=username, password_hash=generate_password_hash(password))
    db.session.add(new_user)
    db.session.commit()

    return jsonify({"message": "User created successfully"}), 201

@app.route('/login', methods=['POST'])
def login():
    data = request.json
    username = data.get('username')
    password = data.get('password')

    user = User.query.filter_by(username=username).first()
    if user and check_password_hash(user.password_hash, password):
        access_token = create_access_token(identity=user.id)
        return jsonify(access_token=access_token), 200

    return jsonify({"message": "Invalid username or password"}), 401

# API Routes
@app.route('/analyze_food', methods=['POST'])
@jwt_required()
def analyze_food():
    data = request.json
    image_data = base64.b64decode(data['image'])
    lidar_data = np.array(data['lidar'])

    image = Image.open(io.BytesIO(image_data))

    # Process image and LiDAR data
    volume = calculate_volume(lidar_data)
    image_description = describe_image(image)

    # Use GPT-4 to analyze the food
    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a nutritionist analyzing food images and LiDAR data."},
            {"role": "user", "content": f"Analyze this food image and estimate its calorie content. The volume is approximately {volume:.2f} cubic centimeters. Image description: {image_description}"}
        ]
    )

    analysis = response.choices[0].message.content

    # Extract food name and calories from the analysis
    food_name = analysis.split('\n')[0]
    calories = int(analysis.split('\n')[1].split(':')[1].strip())

    return jsonify({
        "foodName": food_name,
        "calories": calories,
        "analysis": analysis
    })

@app.route('/log_food', methods=['POST'])
@jwt_required()
def log_food():
    user_id = get_jwt_identity()
    data = request.json
    new_log = FoodLog(
        id=data['id'],
        user_id=user_id,
        food_name=data['foodName'],
        calories=data['calories'],
        date=datetime.fromisoformat(data['date'])
    )
    db.session.add(new_log)
    db.session.commit()
    return jsonify({"message": "Food logged successfully"}), 201

@app.route('/get_food_logs', methods=['GET'])
@jwt_required()
def get_food_logs():
    user_id = get_jwt_identity()
    date_str = request.args.get('date')
    date = datetime.fromisoformat(date_str)

    logs = FoodLog.query.filter_by(user_id=user_id).filter(
        FoodLog.date >= date.replace(hour=0, minute=0, second=0),
        FoodLog.date < date.replace(hour=0, minute=0, second=0) + timedelta(days=1)
    ).order_by(FoodLog.date.desc()).all()

    return jsonify([
        {
            "id": log.id,
            "foodName": log.food_name,
            "calories": log.calories,
            "date": log.date.isoformat()
        }
        for log in logs
    ])

@app.route('/update_profile', methods=['POST'])
@jwt_required()
def update_profile():
    user_id = get_jwt_identity()
    data = request.json
    user = User.query.get(user_id)
    if user:
        user.username = data['username']
        user.daily_calorie_goal = data['daily_calorie_goal']
        db.session.commit()
        return jsonify({"message": "Profile updated successfully"}), 200
    return jsonify({"message": "User not found"}), 404

@app.route('/get_nutrition_insights', methods=['GET'])
@jwt_required()
def get_nutrition_insights():
    user_id = get_jwt_identity()
    user = User.query.get(user_id)

    # Calculate weekly calorie data
    today = datetime.now().date()
    week_start = today - timedelta(days=today.weekday())
    weekly_calorie_data = []
    for i in range(7):
        date = week_start + timedelta(days=i)
        calories = db.session.query(db.func.sum(FoodLog.calories)).filter(
            FoodLog.user_id == user_id,
            FoodLog.date >= date,
            FoodLog.date < date + timedelta(days=1)
        ).scalar() or 0
        weekly_calorie_data.append(calories)

    # Calculate nutrient breakdown (simplified)
    total_calories = sum(weekly_calorie_data)
    nutrient_breakdown = [
        total_calories * 0.3,  # Protein
        total_calories * 0.3,  # Carbs
        total_calories * 0.4   # Fat
    ]

    # Generate insights
    avg_daily_calories = total_calories / 7
    insights = [
        f"Your average daily calorie intake this week was {avg_daily_calories:.0f} calories.",
        f"Your calorie goal is {user.daily_calorie_goal} calories per day.",
    ]
    if avg_daily_calories > user.daily_calorie_goal:
        insights.append(
            "You're currently above your calorie goal. Consider reducing portion sizes or choosing lower-calorie options.")
    elif avg_daily_calories < user.daily_calorie_goal:
        insights.append(
            "You're currently below your calorie goal. Make sure you're eating enough to meet your nutritional needs.")

    return jsonify({
        "weeklyCalorieData": weekly_calorie_data,
        "nutrientBreakdown": nutrient_breakdown,
        "insights": insights
    })


def calculate_volume(lidar_data):
    depth_map = lidar_data.reshape((len(lidar_data) // 256, 256))
    volume = np.sum(depth_map) * (depth_map.shape[0] / 1000) * (depth_map.shape[1] / 1000)
    return volume


def describe_image(image):
    # In a production environment, you would use a proper computer vision model.
    # For now, we'll use GPT-4o-mini for image description
    buffered = io.BytesIO()
    image.save(buffered, format="PNG")
    img_str = base64.b64encode(buffered.getvalue()).decode()

    response = client.chat.completions.create(
        model="gpt-4o-mini",
        messages=[
            {"role": "system", "content": "You are a computer vision system. Describe the food in this image."},
            {"role": "user", "content": f"[A base64 encoded image of food: {img_str}]"}
        ]
    )

    return response.choices[0].message.content


if __name__ == '__main__':
    with app.app_context():
        db.create_all()
    app.run(debug=False, host='0.0.0.0')