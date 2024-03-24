#!/bin/bash

sed "s|BACKENDURL|$( cat ./site.env )|" ./site/template.html > ./site/index.html
