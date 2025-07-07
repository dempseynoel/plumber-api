# R REST APIs with plumber

*This is recreating a previously deleted repository.* 

You've just created a machine learning model or a piece of analysis in R and want to make it available to others to use. One way to share your work is to transform it into a web service - i.e. an API. Other developers would therefore only need to learn how to interact with your API, rather than how to code in R, to use your model or analysis. The `plumber` R package is the tool to do that: it allows us to expose R code as a service available to any other service on the web.

This guide provides an overview of how to create a REST API in R using the `plumber` package, containerise with Docker, and deploy on the cloud (Azure in this example). Official `plumber` documentation can be found [here](https://www.rplumber.io). 

## Creating an API

Let's imagine you have a few functions which transform data from the [Gapminder foundation](https://www.gapminder.org). `plumber` allows you to create APIs by decorating this exsting R code with special annotations that start with `#*`. The example below shows a file named `plumber.R` which contains the user created functions, as well as their transformation into a `plumber` API.

``` r
 File name: plumber.R

# Packages --------------------------------------------------------------------

library(dplyr)
library(gapminder)

# Existing functions ----------------------------------------------------------

# Function 1: Countries
countries <- function(selected_continent, life_expectancy, population) {
  gapminder %>% 
    filter(
      year == 2007, 
      continent == selected_continent, 
      lifeExp > life_expectancy,
      pop > population)
}

# Function 2: GDP
gdp <- function(selected_country) {
  gapminder %>% 
    filter(
      year == 2007, 
      country == selected_country) %>% 
    summarise(gdp = pop * gdpPercap)
}

# Plumber functions -----------------------------------------------------------

library(plumber)

# API title and description 
#* @apiTitle Gapminder API
#* @apiDescription API for exploring the gapminder dataset

#* Countries
#* @param selected_continent The continent of interest
#* @param life_expectancy Life expectancy greater than
#* @param population Population greater than
#* @get /countries
function(selected_continent, life_expectancy, population) {
  gapminder %>% 
    filter(
      year == 2007, 
      continent == selected_continent, 
      lifeExp > life_expectancy,
      pop > population)
}

#* Calculate GDP
#* @param selected_country The country of interest
#* @get /gdp
function(selected_country) {
  gapminder %>% 
    filter(
      year == 2007, 
      country == selected_country) %>% 
    summarise(gdp = pop * gdpPercap)
}
```

In the example above we have converted our existing functions into two GET API endpoints. If it was needed we could have also created a POST endpoint using `plumber`. Further information on the difference HTTP request methods refer to this [Mozilla documentation](https://developer.mozilla.org/en-US/docs/Web/HTTP/Methods).

Let's now run our API locally and submit requests through [Swagger](https://swagger.io) - once the code below is ran Swagger will open up either in a viewer in RStudio or in your browser (depending on your RStudio settings). 

``` r
api <- plumb(file = 'plumber.R')

# Plumber router with 2 endpoints, 4 filters, and 0 sub-routers.
# Use `pr_run()` on this object to start the API.
├──[queryString]
├──[body]
├──[cookieParser]
├──[sharedSecret]
├──/countries (GET)
└──/gdp (GET)

pr_run(api)
```

![api](/images/countries-endpoint.png)

If we submited a request to the `/countries` endpoint asking for countries in Asia which had a life expectancy greater than 80 and had a population greater than 20 million then we'd get back two entries - Hong Kong and Israel (see the Gapminder website for information on how it codes the dataset).

![result](/images/returned-result.png)
  
## Docker

Now we've converted our R code into an API using `plumber` we can containerise it with Docker. Our Dockerfile will need to have instructions on getting a base image with R installed, installation of the Linux libaries neccessary for `plumber`, the `renv.lock` file describing our package dependencies, exposing an appropriate port, and then an entrypoint to immediately execute our API when the container is ran.

```

# Base image https://hub.docker.com/u/rocker/
FROM rocker/r-ver:4.3.1

# Install the linux libraries needed for plumber 
RUN apt-get update -qq && apt-get install -y \ 
   libssl-dev \ 
   libcurl4-gnutls-dev \
   libsodium-dev
   
# Copy necessary files
COPY renv.lock ./renv.lock
COPY plumber.R .

# Install renv & restore packages
RUN Rscript -e 'install.packages("renv")'
RUN Rscript -e 'renv::restore()'

# Expose port
EXPOSE 8000

ENTRYPOINT ["R", "-e", \
    "r = plumber::plumb('plumber.R'); r$run(host = '0.0.0.0', port = 8000)"]

```
We can now build an image with the Dockerfile and run a container on our machine.

```
docker build -t plumber-api .
docker run -p 8000:8000 -d --name my-first-api plumber-api
```

Once it's completed building the image, and started a container we should be able to go to our `http://localhost:8000/__docs__/` and see the API working. 

## Setting up Azure Container Registry

The first step towards hosting our API is to create an Azure Container Registry to store our Docker image in. Azure Container Registry is a private registry service for building, storing, and managing container images and other related artifacts. To set up ACR, go to the Azure Portal, login and create a new Container Registry. 

![result](/images/container-registry.png)

Once there, fill in all the required information. If you don’t have a resource group yet, you need to create one.

![result](/images/create-registry.png)

Click ‘review + create’. When deployment of the resource is finished you can visit your resource. The next thing you want to do is to enable the admin user. You can do that at ‘Access keys’ under ‘Settings’. This allows you to publish a Docker image to the registry from the Terminal.

![result](/images/acr-admin.png)

We now need to push our image to the ACR, to do this we can call the following commands:

```
docker tag plumber-api:latest rwgplumberapi.azurecr.io/plumber-api:latest
docker login rwgplumberapi.azurecr.io

# Username = The username under acess keys of the ACR registry we created
# Password = The password generated under access keys of the ACR registry we created
# Once you're signed in...

docker push rwgplumberapi.azurecr.io/plumber-api:latest

# Our image will be pushed to Azure.
# This will be visible under repositories of the ACR registry we made.

```

## Using Azure App Service to host your Plumber API

After finishing pushing the image to your container registry, we can deploy the image to Azure App Service.
Azure App Service enables you to build and host web apps and web services in any programming language without managing infrastructure. It offers features like auto-scaling and high availability, supports Linux and Windows, and enables automated deployments from any Git repo. Azure App Services offers standard runtime stacks, but you can also use a custom Docker image to run your web app. Just like we’re going to do.
First you need to create a new Web App resource:

![result](/images/azure-webapp.png)

Fill in the required details and pick ‘Docker container’ as publishing choice. You’ll need an App Service Plan to add your Web App to.

![result](/images/create-webapp-resource.png)

The next step is the Docker configuration:

![result](/images/webapp-docker.png)

The images will be automatically retrieved once you select your registry. Click ‘review + create’ and wait for deployment to be finished.
And that’s it! You’re now able to access your R Plumber API via your browser, Postman, or your terminal:

![result](/images/api-output.png)

## Recap and next steps

To recap, we've converted some existing R code into an API using the `plumber` package, containerised with Docker, and deploy to the cloud with Azure. Anyone, or any application, with details of our API can call it to retrieve data. In this instance, we've only used a simple example, however it's just as easy to take a model you've developed in R and create a POST endpoint for it and deploy it the same way. We'd then be able to send the API data to make predictions. A how-to guide on how to do this will follow this walkthrough. 

### NOTE
As our API is now exposed to the world we should put some security around it, for example we ideally would want to add some authentication to it - we could use Azure API Management to achieve that.

*On the last two images you may notice differences in the registry name when creating the web app and the URL of the API...this is just because I forgot to grab images as I went through the guide. To be consistent with the rest imagine these are actually rwgplumberapi.*

