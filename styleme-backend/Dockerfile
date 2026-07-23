FROM python:3.11-slim

# Dependencias de sistema para opencv (ultralytics) y onnxruntime
RUN apt-get update && apt-get install -y --no-install-recommends \
    libgl1 libglib2.0-0 libgomp1 \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# torch CPU-only desde el índice de PyTorch (evita ~2.5GB de CUDA)
RUN pip install --no-cache-dir --index-url https://download.pytorch.org/whl/cpu \
    torch==2.12.1 torchvision==0.27.1

# Resto de dependencias (versiones pineadas = build reproducible)
COPY styleme-backend/requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt \
    scikit-learn==1.9.0 ultralytics==8.4.81 onnxruntime==1.21.0 \
    rembg==2.0.76 numpy==2.4.6

# Código del backend
COPY styleme-backend/main.py .
COPY styleme-backend/app ./app

# Modelos ML (están en la raíz del repo, por eso el contexto es la raíz)
COPY modelo_color.pkl modelo_recomendador_outfits.pkl styleme_detector.pt ./models/

RUN mkdir -p /app/uploads

EXPOSE 8000
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]
