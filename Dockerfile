# Use an official Nginx runtime as a parent image
FROM nginx:alpine

# Set working directory
WORKDIR /usr/share/nginx/html

# Remove default Nginx static assets
RUN rm -rf ./*

# Copy static assets from static-website folder to the Nginx public directory
COPY static-website/ .

# Create a custom Nginx configuration
# Assumes nginx.conf is in the root of the build context (same level as Dockerfile)
COPY nginx.conf /etc/nginx/conf.d/default.conf

# Expose port 8080 (as defined in nginx.conf)
EXPOSE 8080

# Command to run Nginx
CMD ["nginx", "-g", "daemon off;"]
