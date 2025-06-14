# Use an official Nginx runtime as a parent image
FROM nginx:alpine

# Set the working directory in the container
WORKDIR /usr/share/nginx/html

# Remove default Nginx welcome page
RUN rm -rf ./*

# Copy the static website files from the 'welcome' folder into the Nginx HTML directory
# This assumes your Dockerfile is in the root and 'welcome' is a subdirectory.
COPY welcome/ .

# Expose port 80 to the outside world
EXPOSE 80

# Command to run Nginx when the container starts
CMD ["nginx", "-g", "daemon off;"]
