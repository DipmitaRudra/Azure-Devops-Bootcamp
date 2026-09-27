# Use an Official Nginx Runtime as the Base Image
FROM nginx:1.31.5-alpine

# Set the Working Directory in the Container
WORKDIR /usr/share/nginx/html

# Copy Application Files/Codes to the Working Directory
COPY index.html .
COPY main.js .
COPY stylesheet.css .
COPY Assets ./Assets

# Expose the Port on which the Nginx Application runs
EXPOSE 80

# Nginx runs automatically with its default CMD