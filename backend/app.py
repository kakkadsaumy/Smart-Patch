from fastapi import FastAPI, UploadFile, File
from fastapi.responses import JSONResponse
import torch
import numpy as np
from model_utils import load_model, preprocess_image

app = FastAPI()

model, idx_to_class, device = load_model("model/model.pt")

@app.post("/predict")
async def predict(image: UploadFile = File(...)):
    contents = await image.read()

    tensor = preprocess_image(contents).to(device)

    with torch.no_grad():
        outputs = model(tensor)
        probs = torch.softmax(outputs, dim=1).cpu().numpy()[0]

    pred_idx = int(np.argmax(probs))
    confidence = float(probs[pred_idx])
    label = idx_to_class[pred_idx]

    advice_map = {
        "early_blight": [
            "Remove infected leaves immediately",
            "Avoid overhead watering",
            "Apply copper-based fungicide"
        ],
        "healthy": [
            "Plant appears healthy",
            "Continue proper irrigation and monitoring"
        ]
    }

    advice = advice_map.get(label.lower(), ["No advice available"])

    return JSONResponse({
        "prediction": label,
        "confidence": round(confidence, 3),
        "advice": advice
    })