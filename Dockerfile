FROM python:3.12-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

COPY pyproject.toml README.md LICENSE ./
COPY src ./src
COPY config ./config
COPY tests/fixtures ./tests/fixtures

RUN pip install --no-cache-dir .

CMD ["sh", "-c", "python tests/fixtures/make_synthetic.py --output-dir data/synthetic && python -m ipo_lottery run --stage all"]

