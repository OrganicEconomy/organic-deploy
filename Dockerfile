FROM node:22

WORKDIR /organic-webserver
COPY package*.json ./
RUN npm install --omit=dev
COPY . .
CMD ["npm", "start"]
