FROM python:3.11-slim

WORKDIR /app

# Install dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy service code
COPY usage-service.py .

# Expose port
EXPOSE 8080

# Run with gunicorn
CMD ["gunicorn", "-w", "2", "-b", "0.0.0.0:8080", "usage-service:app"]

