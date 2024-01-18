FROM python:3.9-alpine

ENV PYTHONUNBUFFERED=1

WORKDIR /app/

COPY . ./

RUN apk -U upgrade && \
    apk add --no-cache gcc musl-dev python3-dev libffi-dev openssl-dev cargo && \
    pip install -U pip wheel && \
    pip install --no-cache-dir -Ur requirements.txt && \
    apk del gcc musl-dev python3-dev libffi-dev openssl-dev cargo

#VOLUME ["/app/public/"]

EXPOSE 8000

ENTRYPOINT ["./docker-entrypoint.sh"]
