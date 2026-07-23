FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

LABEL version="2.3.1" description="Api to control whatsapp features through http requests." 
LABEL maintainer="Davidson Gomes" git="https://github.com/DavidsonGomes"
LABEL contact="contato@evolution-api.com"

WORKDIR /evolution

COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

RUN npm ci --silent

COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./.env.example ./.env
COPY ./runWithProvider.js ./

COPY ./Docker ./Docker

RUN chmod +x ./Docker/scripts/* && dos2unix ./Docker/scripts/*

RUN ./Docker/scripts/generate_database.sh

RUN npm run build

FROM node:24-alpine AS final

# postgresql16 = Postgres embebido, su-exec = para correr comandos como user "postgres"
RUN apk update && \
    apk add tzdata ffmpeg bash openssl postgresql16 postgresql16-contrib su-exec

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true

WORKDIR /evolution

COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json

COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/manager ./manager
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/.env ./.env
COPY --from=builder /evolution/Docker ./Docker
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
COPY --from=builder /evolution/tsup.config.ts ./tsup.config.ts

# Script que arranca Postgres local y luego la API (va codificado en base64 para evitar líos de comillas)
RUN echo "IyEvYmluL3NoCnNldCAtZQoKbWtkaXIgLXAgL3Zhci9saWIvcG9zdGdyZXNxbC9kYXRhCmNob3duIC1SIHBvc3RncmVzOnBvc3RncmVzIC92YXIvbGliL3Bvc3RncmVzcWwKCmlmIFsgISAtcyAvdmFyL2xpYi9wb3N0Z3Jlc3FsL2RhdGEvUEdfVkVSU0lPTiBdOyB0aGVuCiAgZWNobyAiSW5pY2lhbGl6YW5kbyBjbHVzdGVyIGRlIFBvc3RncmVzLi4uIgogIHN1LWV4ZWMgcG9zdGdyZXMgaW5pdGRiIC1EIC92YXIvbGliL3Bvc3RncmVzcWwvZGF0YQpmaQoKc3UtZXhlYyBwb3N0Z3JlcyBwZ19jdGwgLUQgL3Zhci9saWIvcG9zdGdyZXNxbC9kYXRhIC1sIC92YXIvbGliL3Bvc3RncmVzcWwvbG9nZmlsZSAtbyAiLWggMC4wLjAuMCAtcCA1NDMyIiBzdGFydAoKZWNobyAiRXNwZXJhbmRvIGEgcXVlIFBvc3RncmVzIHJlc3BvbmRhLi4uIgp1bnRpbCBzdS1leGVjIHBvc3RncmVzIHBnX2lzcmVhZHkgLWggbG9jYWxob3N0IC1wIDU0MzIgPi9kZXYvbnVsbCAyPiYxOyBkbwogIHNsZWVwIDEKZG9uZQoKUk9MRV9FWElTVFM9JChzdS1leGVjIHBvc3RncmVzIHBzcWwgLWggbG9jYWxob3N0IC1wIDU0MzIgLXRBYyAiU0VMRUNUIDEgRlJPTSBwZ19yb2xlcyBXSEVSRSByb2xuYW1lPSdldm9sdXRpb24nIiB8fCBlY2hvICIiKQppZiBbICIkUk9MRV9FWElTVFMiICE9ICIxIiBdOyB0aGVuCiAgZWNobyAiQ3JlYW5kbyB1c3VhcmlvIHkgYmFzZSBkZSBkYXRvcyBldm9sdXRpb24uLi4iCiAgc3UtZXhlYyBwb3N0Z3JlcyBwc3FsIC1oIGxvY2FsaG9zdCAtcCA1NDMyIC1jICJDUkVBVEUgVVNFUiBldm9sdXRpb24gV0lUSCBTVVBFUlVTRVIgUEFTU1dPUkQgJ2V2b2x1dGlvbic7IgogIHN1LWV4ZWMgcG9zdGdyZXMgcHNxbCAtaCBsb2NhbGhvc3QgLXAgNTQzMiAtYyAiQ1JFQVRFIERBVEFCQVNFIGV2b2x1dGlvbiBPV05FUiBldm9sdXRpb247IgpmaQoKZWNobyAiUG9zdGdyZXMgbGlzdG8uIEFycmFuY2FuZG8gRXZvbHV0aW9uIEFQSS4uLiIKLiAuL0RvY2tlci9zY3JpcHRzL2RlcGxveV9kYXRhYmFzZS5zaApleGVjIG5wbSBydW4gc3RhcnQ6cHJvZAo=" | base64 -d > /start.sh && chmod +x /start.sh

ENV DOCKER_ENV=true
ENV DATABASE_PROVIDER=postgresql
ENV DATABASE_CONNECTION_URI="postgresql://evolution:evolution@localhost:5432/evolution?schema=public"

EXPOSE 8080

ENTRYPOINT ["/start.sh"]