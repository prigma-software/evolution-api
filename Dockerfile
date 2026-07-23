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

RUN echo "IyEvYmluL3NoCnNldCAtZQoKbWtkaXIgLXAgL3Zhci9saWIvcG9zdGdyZXNxbC9kYXRhCm1rZGlyIC1wIC9ydW4vcG9zdGdyZXNxbApjaG93biAtUiBwb3N0Z3Jlczpwb3N0Z3JlcyAvdmFyL2xpYi9wb3N0Z3Jlc3FsCmNob3duIC1SIHBvc3RncmVzOnBvc3RncmVzIC9ydW4vcG9zdGdyZXNxbAoKaWYgWyAhIC1zIC92YXIvbGliL3Bvc3RncmVzcWwvZGF0YS9QR19WRVJTSU9OIF07IHRoZW4KICBlY2hvICJJbmljaWFsaXphbmRvIGNsdXN0ZXIgZGUgUG9zdGdyZXMuLi4iCiAgc3UtZXhlYyBwb3N0Z3JlcyBpbml0ZGIgLUQgL3Zhci9saWIvcG9zdGdyZXNxbC9kYXRhCmZpCgpzdS1leGVjIHBvc3RncmVzIHBnX2N0bCAtRCAvdmFyL2xpYi9wb3N0Z3Jlc3FsL2RhdGEgLWwgL3Zhci9saWIvcG9zdGdyZXNxbC9sb2dmaWxlIFwKICAtbyAiLWggMC4wLjAuMCAtcCA1NDMyIC1jIHNoYXJlZF9idWZmZXJzPTMyTUIgLWMgZHluYW1pY19zaGFyZWRfbWVtb3J5X3R5cGU9cG9zaXggLWMgbWF4X2Nvbm5lY3Rpb25zPTIwIiBcCiAgc3RhcnQgfHwgewogICAgZWNobyAiPT09IFBvc3RncmVzIG5vIGFycmFuY8OzLCBlc3RvIHNhbGlvIGVuIGVsIGxvZzogPT09IgogICAgY2F0IC92YXIvbGliL3Bvc3RncmVzcWwvbG9nZmlsZQogICAgZXhpdCAxCiAgfQoKZWNobyAiRXNwZXJhbmRvIGEgcXVlIFBvc3RncmVzIHJlc3BvbmRhLi4uIgp0cmllcz0wCnVudGlsIHN1LWV4ZWMgcG9zdGdyZXMgcGdfaXNyZWFkeSAtaCBsb2NhbGhvc3QgLXAgNTQzMiA+L2Rldi9udWxsIDI+JjE7IGRvCiAgc2xlZXAgMQogIHRyaWVzPSQoKHRyaWVzKzEpKQogIGlmIFsgIiR0cmllcyIgLWd0IDMwIF07IHRoZW4KICAgIGVjaG8gIj09PSBQb3N0Z3JlcyBudW5jYSByZXNwb25kaW8sIGxvZzogPT09IgogICAgY2F0IC92YXIvbGliL3Bvc3RncmVzcWwvbG9nZmlsZQogICAgZXhpdCAxCiAgZmkKZG9uZQoKUk9MRV9FWElTVFM9JChzdS1leGVjIHBvc3RncmVzIHBzcWwgLWggbG9jYWxob3N0IC1wIDU0MzIgLXRBYyAiU0VMRUNUIDEgRlJPTSBwZ19yb2xlcyBXSEVSRSByb2xuYW1lPSdldm9sdXRpb24nIiB8fCBlY2hvICIiKQppZiBbICIkUk9MRV9FWElTVFMiICE9ICIxIiBdOyB0aGVuCiAgZWNobyAiQ3JlYW5kbyB1c3VhcmlvIHkgYmFzZSBkZSBkYXRvcyBldm9sdXRpb24uLi4iCiAgc3UtZXhlYyBwb3N0Z3JlcyBwc3FsIC1oIGxvY2FsaG9zdCAtcCA1NDMyIC1jICJDUkVBVEUgVVNFUiBldm9sdXRpb24gV0lUSCBTVVBFUlVTRVIgUEFTU1dPUkQgJ2V2b2x1dGlvbic7IgogIHN1LWV4ZWMgcG9zdGdyZXMgcHNxbCAtaCBsb2NhbGhvc3QgLXAgNTQzMiAtYyAiQ1JFQVRFIERBVEFCQVNFIGV2b2x1dGlvbiBPV05FUiBldm9sdXRpb247IgpmaQoKZWNobyAiUG9zdGdyZXMgbGlzdG8uIEFycmFuY2FuZG8gRXZvbHV0aW9uIEFQSS4uLiIKLiAuL0RvY2tlci9zY3JpcHRzL2RlcGxveV9kYXRhYmFzZS5zaApleGVjIG5wbSBydW4gc3RhcnQ6cHJvZAo=" | base64 -d > /start.sh && chmod +x /start.sh

ENV DOCKER_ENV=true
ENV DATABASE_PROVIDER=postgresql
ENV DATABASE_CONNECTION_URI="postgresql://evolution:evolution@localhost:5432/evolution?schema=public"

EXPOSE 8080

ENTRYPOINT ["/start.sh"]