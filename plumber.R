

# Title: Develop and deploy a simple R REST API with Plumber
# Date: 28 August 2023
# Author: noel.dempsey@capgemini.com


# File name: plumber.R

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

# Function 2: Calculate GDP
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

