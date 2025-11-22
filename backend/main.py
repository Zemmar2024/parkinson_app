import os
import io
import base64
import random
import datetime
from typing import List, Optional
import numpy as np

#import tensorflow as tf
#from tensorflow.keras.models import load_model
#from tensorflow.keras.preprocessing import image

from fastapi import FastAPI, Depends, HTTPException, UploadFile, File, Form
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy import create_engine, Column, Integer, String, Float, Boolean, DateTime
from sqlalchemy.ext.declarative import declarative_base
from sqlalchemy.orm import sessionmaker, Session
from pydantic import BaseModel
from PIL import Image, ImageDraw

# --- Configuration ---
DATABASE_URL = "sqlite:///./parkinson.db"
UPLOAD_DIR = "uploads"
os.makedirs(UPLOAD_DIR, exist_ok=True)

# --- Database Setup ---
engine = create_engine(DATABASE_URL, connect_args={"check_same_thread": False})
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)
Base = declarative_base()



class UserDB(Base):
    __tablename__ = "users"
    id = Column(Integer, primary_key=True, index=True)
    username = Column(String, unique=True, index=True)
    password = Column(String)  # In production, hash this!
    is_admin = Column(Boolean, default=False)

class DrawingDB(Base):
    __tablename__ = "drawings"
    id = Column(Integer, primary_key=True, index=True)
    user_id = Column(Integer, index=True)
    image_path = Column(String)
    prediction_score = Column(Float) # 0.0 (Healthy) to 1.0 (Parkinson's)
    timestamp = Column(DateTime, default=datetime.datetime.utcnow)

Base.metadata.create_all(bind=engine)


# --- Chargement du Modèle IA ---
#print("Chargement du modèle en cours...")
#try:
    # Assurez-vous que model.h5 est dans le même dossier ou indiquez le chemin
#    MODEL = load_model("model.h5") 
#    print("Modèle chargé avec succès !")
#except Exception as e:
#    print(f"Erreur lors du chargement du modèle : {e}")
#    MODEL = None

MODEL = None

# --- FastAPI App ---
app = FastAPI()

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# --- Dependency ---
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()

# --- Pydantic Models ---
class UserSignup(BaseModel):
    username: str
    password: str

class UserLogin(BaseModel):
    username: str
    password: str


# Ajoutez ceci avec les autres classes Pydantic
class UserListResponse(BaseModel):
    id: int
    username: str
    is_admin: bool
    
    class Config:
        orm_mode = True


class PredictionResponse(BaseModel):
    score: float
    label: str
    lime_explanation: str # Base64 image string

# --- ML Helper Functions (Mocked for MVP) ---
def mock_predict_parkinsons(image_path: str):
    # TODO: Load your actual .h5 model here
   return random.uniform(0, 1)

def predict_parkinsons_real(image_path: str):
    if MODEL is None:
        return 0.5 # Retourne une valeur par défaut si le modèle a planté
    
    # 1. Charger l'image et la redimensionner à la taille attendue par le modèle
    # IMPORTANT : Remplacez (128, 128) par la taille utilisée lors de votre entraînement !
    img = image.load_img(image_path, target_size=(224, 224), color_mode="rgb") # ou "grayscale" si N&B
    
    # 2. Convertir en tableau de nombres (Array)
    img_array = image.img_to_array(img)
    
    # 3. Normaliser (diviser par 255) si vous l'avez fait à l'entraînement
    img_array = img_array / 255.0
    
    # 4. Ajouter une dimension pour créer un "batch" (le modèle attend [1, 224, 224, 3])
    img_array = np.expand_dims(img_array, axis=0)
    
    # 5. Faire la prédiction
    prediction = MODEL.predict(img_array)
    
    # 6. Récupérer le score (supposons que c'est une sortie binaire 0 à 1)
    score = float(prediction[0][0])
    return score

def mock_lime_explanation(image_path: str):
    # TODO: Apply LIME here. 
    # This mocks a heatmap overlay.
    img = Image.open(image_path).convert("RGBA")
    overlay = Image.new('RGBA', img.size, (255, 0, 0, 0))
    draw = ImageDraw.Draw(overlay)
    draw.ellipse((50, 50, 250, 250), fill=(255, 0, 0, 100))
    combined = Image.alpha_composite(img, overlay)
    buffered = io.BytesIO()
    combined.save(buffered, format="PNG")
    return base64.b64encode(buffered.getvalue()).decode('utf-8')

# --- Routes ---
@app.post("/signup")
def signup(user: UserSignup, db: Session = Depends(get_db)):
    db_user = db.query(UserDB).filter(UserDB.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    is_admin = user.username.lower() == "admin"
    new_user = UserDB(username=user.username, password=user.password, is_admin=is_admin)
    db.add(new_user)
    db.commit()
    return {"message": "User created"}

@app.post("/login")
def login(user: UserLogin, db: Session = Depends(get_db)):
    db_user = db.query(UserDB).filter(UserDB.username == user.username).first()
    if not db_user or db_user.password != user.password:
        raise HTTPException(status_code=400, detail="Invalid credentials")
    return {"user_id": db_user.id, "is_admin": db_user.is_admin, "username": db_user.username}

@app.post("/predict", response_model=PredictionResponse)
async def predict(
    user_id: int = Form(...), 
    file: UploadFile = File(...), 
    db: Session = Depends(get_db)
):
    file_location = f"{UPLOAD_DIR}/{user_id}_{datetime.datetime.now().timestamp()}.png"
    with open(file_location, "wb") as f:
        f.write(await file.read())
    
    # score = mock_predict_parkinsons(file_location)
   # score = predict_parkinsons_real(file_location)
    score = mock_predict_parkinsons(file_location)
    label = "High Risk Parkinson" if score > 0.5 else "Healthy"
    lime_b64 = mock_lime_explanation(file_location)
    
    db_drawing = DrawingDB(user_id=user_id, image_path=file_location, prediction_score=score)
    db.add(db_drawing)
    db.commit()
    
    return {
        "score": score,
        "label": label,
        "lime_explanation": lime_b64
    }

@app.get("/history/{user_id}")
def get_history(user_id: int, db: Session = Depends(get_db)):
    drawings = db.query(DrawingDB).filter(DrawingDB.user_id == user_id).order_by(DrawingDB.timestamp.desc()).all()
    return drawings

@app.get("/admin/stats")
def get_stats(db: Session = Depends(get_db)):
    total_users = db.query(UserDB).count()
    total_drawings = db.query(DrawingDB).count()
    avg_score = 0
    drawings = db.query(DrawingDB).all()
    if drawings:
        avg_score = sum([d.prediction_score for d in drawings]) / len(drawings)
    return {
        "total_users": total_users,
        "total_drawings": total_drawings,
        "average_risk_score": avg_score
    }


@app.get("/admin/users", response_model=List[UserListResponse])
def get_all_users(admin_id: int, db: Session = Depends(get_db)):
    # 1. Vérifier si celui qui demande est bien un admin
    admin = db.query(UserDB).filter(UserDB.id == admin_id).first()
    if not admin or not admin.is_admin:
        raise HTTPException(status_code=403, detail="Accès refusé : Vous n'êtes pas admin")

    # 2. Récupérer tous les utilisateurs
    users = db.query(UserDB).all()
    return users




@app.delete("/admin/users/{user_id_to_delete}")
def delete_user(user_id_to_delete: int, admin_id: int, db: Session = Depends(get_db)):
    # 1. Vérifier si celui qui demande est bien un admin
    admin = db.query(UserDB).filter(UserDB.id == admin_id).first()
    if not admin or not admin.is_admin:
        raise HTTPException(status_code=403, detail="Accès refusé : Vous n'êtes pas admin")

    # 2. Empêcher l'admin de se supprimer lui-même (sécurité)
    if user_id_to_delete == admin_id:
        raise HTTPException(status_code=400, detail="Vous ne pouvez pas supprimer votre propre compte admin")

    # 3. Trouver l'utilisateur à supprimer
    user = db.query(UserDB).filter(UserDB.id == user_id_to_delete).first()
    if not user:
        raise HTTPException(status_code=404, detail="Utilisateur non trouvé")

    # 4. Supprimer aussi ses dessins (Nettoyage)
    db.query(DrawingDB).filter(DrawingDB.user_id == user_id_to_delete).delete()

    # 5. Supprimer l'utilisateur
    db.delete(user)
    db.commit()

    return {"message": f"L'utilisateur {user.username} et ses données ont été supprimés."}




if __name__ == "__main__":
    import uvicorn
    uvicorn.run(app, host="0.0.0.0", port=8000)
