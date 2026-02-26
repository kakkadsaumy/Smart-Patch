from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
import random

app = FastAPI()

@app.post("/predict")
async def predict(image: UploadFile = File(...)):
    await image.read()

    prediction = random.choice(["early_blight", "healthy"])

    if prediction == "early_blight":
        confidence = round(random.uniform(0.75, 0.95), 3)
        advice = [
            "Remove infected leaves immediately",
            "Avoid overhead watering",
            "Apply copper-based fungicide"
        ]
    else:
        confidence = round(random.uniform(0.75, 0.95), 3)
        advice = [
            "Plant appears healthy",
            "Continue proper irrigation and monitoring"
        ]

    return JSONResponse({
        "prediction": prediction,
        "confidence": confidence,
        "advice": advice
    })