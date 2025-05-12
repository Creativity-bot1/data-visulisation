import javax.swing.*;
PImage img;
PShape mapPlane;
int currentYear = 1991;
String currentRegion = "All";
String currentView = "Custom";
Table data;
int lastClickTime = 0;
int doubleClickTimeout = 400; 
int click_count = 0;
float minZoom = 90; // max zoomed in distance
float maxZoom = 900; // max zoomed out distance

// My Camera control variables 
float camX = 0;
float camY = 0;
float camZ = 800; 
float rotationX = 0;
float rotationY = 0;


// Data structures
ArrayList<City> cities = new ArrayList<City>();
HashMap<String, ArrayList<City>> regions = new HashMap<String, ArrayList<City>>();

// City Input Variables
String selectedCity = "";
boolean cityNameRequired = false;
float cityInputX = 0;
float cityInputY = 0;

// Vairables to control shape of bars
float BAR_WIDTH = 8.0;
float MIN_HEIGHT = 15.0;
float MAX_HEIGHT = 150.0;
float MIN_POP = 1000.0;
float MAX_POP = 8000000.0;

//  check if a column exists
boolean tableHasColumn(Table table, String columnName) {
  for (String col : table.getColumnTitles()) {
    if (col.equalsIgnoreCase(columnName)) return true;
  }
  return false;
}

void setup() {
  size(700, 800, P3D);
  img = loadImage("uk-admin.jpg");
  
    println("Use the arrow keys or 'w','a','s','d' to pan around the map");
    println("Use the Mouse wheel to zoom in and out ");
    println("Double Left and right Click for Snap view ");
    println("Press '1' to view the Census from 1991");
    println("Press '2' to view the Census from 2001");
    println("Press '3' to view the Census from 2011");
    println("HOLD 'z' and left click on the city to retreive coordinates");
    println("Press 'esc' to close down app if not wanting to enter a city name else type in nan and the cooordinates of clicked posotion will be received");
    println("ENJOY");
    
    
  // Create textured plane
  textureMode(NORMAL);
  mapPlane = createShape();
  mapPlane.beginShape(QUAD);
  mapPlane.texture(img);
  mapPlane.vertex(-width/2, -height/2, 0, 0, 0);
  mapPlane.vertex(width/2, -height/2, 0, 1, 0);
  mapPlane.vertex(width/2, height/2, 0, 1, 1);
  mapPlane.vertex(-width/2, height/2, 0, 0, 1);
  mapPlane.endShape();
  
  // Load city data
  loadCityData();
  
  // Initialize lighting
  ambientLight(100, 100, 100);
  directionalLight(255, 255, 255, 0, 1, -1);
  specular(255, 255, 255);
}


void draw() {
  background(0);
  
  // Set camera perspective with adjusted near/far planes
  perspective(PI/3.0, float(width)/float(height), 1, 10000);
  
  
  // Apply camera transformations
  pushMatrix();
  
  // First translate to center of screen
  translate(width/2, height/2, 0);
  
  // Apply rotations
  rotateX(rotationX);
  rotateY(rotationY);
  
  // Applies zoom 
  float zoomScale = map(camZ, minZoom, maxZoom, 4.0, 0.5);
  scale(zoomScale);
  
  // allows camera panning 
  translate(-camX, -camY, 0);
  
  // Draw the map plane
  shape(mapPlane);
  
  // functon to call Draw population bars
  drawPopulationBars();
  
  popMatrix();
  

  // Draw city input prompt when active
  if (cityNameRequired) {
    fill(0, 0, 0, 200);
    rect(0, height - 60, width, 60);
    fill(255);
    textAlign(LEFT);
    textSize(16);
    text("Type city name and press ENTER: " + selectedCity, 20, height - 30);
  }
  
}


void drawPopulationBars() {
  // Calculates scale factor for bar size 
  float barScale = map(camZ, minZoom, maxZoom, 0.5, 1.3);
  
  // Lights for the 3D bars
  lights();
  
  // Calculate the maximum population in the current view for better scaling
  int maxPopInView = 0;
  for (City city : cities) {
    if (city.shouldDisplay(currentRegion)) {
      int pop = city.getPopulation(currentYear);
      if (pop > maxPopInView) maxPopInView = pop;
    }
  }
  
  // Adjust MAX_POP
  float effectiveMaxPop = min(MAX_POP, maxPopInView * 1.2f); 
  

  for (City city : cities) {
    if (city.shouldDisplay(currentRegion)) {
      pushMatrix();
      
      // Position at city coordinates
      translate(city.x, city.y, 0);
      
      // Get population for the current year
      int pop = city.getPopulation(currentYear);
      
      if (pop <= 0) {   // should be used to fill population less than 0 , doesnt work
        fill(100, 100, 100);
        
        popMatrix();
        continue;
      }
    
      // Scale population to bar height 
      float logPop = log(max(pop, MIN_POP));
      float logMin = log(MIN_POP);
      float logMax = log(MAX_POP);
      float h = map(logPop, logMin, logMax, MIN_HEIGHT, MAX_HEIGHT) * barScale;
      
      // Adjust bar width based on population size
      float adjustedBarWidth = map(logPop, logMin, logMax, BAR_WIDTH * 0.5, BAR_WIDTH * 1.2) * barScale;
     
      boolean dataExist = (pop > 0);
       
      if (dataExist) {
        // Color based on population
        colorMode(HSB, 255);
        float hue = map(pop, 0, effectiveMaxPop, 160, 0); // Blue to red
        float saturation = map(pop, 0, effectiveMaxPop, 180, 230); 
        fill(hue, saturation, 230);
        colorMode(RGB, 255);
     
        // Draw 3D bar on the map
        pushMatrix();
        translate(0, 0, h / 2);
        box(adjustedBarWidth, adjustedBarWidth, h);  // Draws the bar
        popMatrix();
          
        // labels the bars with city name and the population
        pushMatrix();
        translate(0, 0, h + 10);
        rotateX(-rotationX);
        rotateY(-rotationY);
        fill(0);
        textSize(10 * barScale);
        textAlign(CENTER); 
        text(city.name, 0, -12);
        text(nfc(pop), 0, 0);
        popMatrix();
        popMatrix();
      }
      
    }
  }
}


// function that uses the world coordinates
void saveCityCoordinates(String cityName, float worldX, float worldY) {
  // Load the data table
  Table table = loadTable("Data.csv", "header");
  
  if (table == null) {
    println("Error: Could not load Data.csv");
    return;
  }
  
  // Ensures X/Y columns exist
  if (!tableHasColumn(table, "X")) table.addColumn("X");
  if (!tableHasColumn(table, "Y")) table.addColumn("Y");
  
  // Search for the city in the table
  for (TableRow row : table.rows()) {
    if (row.getString("City").equalsIgnoreCase(cityName)) {
      row.setFloat("X", worldX);
      row.setFloat("Y", worldY);
      println("Updated coordinates for " + cityName.toLowerCase() + ": X=" + worldX + ", Y=" + worldY);
      break;
    }
  }
    saveTable(table, "Data.csv");
    println("Data saved successfully.");
    
    // Reload the data to see changes
    loadCityData();
  
}

void mouseDragged() {
  // if not trying to enter city name then map can be dragged with mouse 
  if (mouseY > 150 && !cityNameRequired) { 
    float zoomScale = map(camZ, minZoom, maxZoom, 2.5, 0.5);
    float panSpeed = 1.0 / zoomScale;
    camX += (pmouseX - mouseX) * panSpeed;
    camY += (pmouseY - mouseY) * panSpeed;
  }
}

void mouseWheel(MouseEvent event) {
  float e = event.getCount();
  camZ += e * 30 ;
  camZ = constrain(camZ, minZoom, maxZoom);
}

void mouseClicked() {
  // clicks will not be processed if waiting for a name 
  if (cityNameRequired) {
    return;
  }
  
  if ((mouseButton == LEFT)) {
    int currentTime = millis();
    if (currentTime - lastClickTime <=doubleClickTimeout) {
    click_count += 1;
    } else {
      click_count = 1; 
    }
    lastClickTime = currentTime;
    if (click_count % 2 == 0){
         camZ -= 500 ;
         camZ = constrain(camZ, minZoom, maxZoom);
    }
  }
  
  if ((mouseButton == RIGHT)) {
    int currentTime = millis();
    if (currentTime - lastClickTime <=doubleClickTimeout) {
    click_count += 1;
    } else {
      click_count = 1; 
    }
    lastClickTime = currentTime;
    print(click_count);
    if (click_count % 2 == 0){
         camZ += 500 ;
         camZ = constrain(camZ, minZoom, maxZoom);
    }
  }
  
  // Hold the button z and click on the city to add bar
  else if (keyPressed && key == 'z' && mouseY > 150) {
    PVector world = screenToWorld(mouseX, mouseY);
    
    // Store the world coordinates directly
    cityInputX = world.x;
    cityInputY = world.y;
    
    // Draws temp marker on clciked position 
    fill(255, 0, 0);
    ellipse(mouseX, mouseY, 10, 10);
    
    // waits for city name input
    cityNameRequired = true;
    selectedCity = "";
    println("Click detected at world coordinates: " + world.x + ", " + world.y);
    println("Please type city name and press ENTER...");
  }
  
}

// Function that allows calculation of world coordinates
PVector screenToWorld(float sx, float sy) {
  // Adjust for center of screen
  float offsetX = sx - width/2;
  float offsetY = sy - height/2;
  
  // Adjust for current zoom level
  float zoomScale = map(camZ, minZoom, maxZoom, 4.0, 0.5);
 
  // Calculate world coordinates with camera position
  float worldX = offsetX / zoomScale + camX;
  float worldY = offsetY / zoomScale + camY;
  
  return new PVector(worldX, worldY);
}


void cityNameRequired(float x, float y) {
  try {
    // Show input dialog with proper conversion of screen coordinates to world coordinates
    String name = JOptionPane.showInputDialog(
      null,
      "Enter a city name:",
      "Set City Position",
      JOptionPane.PLAIN_MESSAGE
    );
    
    if (name != null && !name.trim().isEmpty()) {
      // Convert screen coordinates to world coordinates before saving
      PVector world = screenToWorld(x, y);
      saveCityCoordinates(name.trim(), world.x, world.y);
    } else {
      println("City position not saved - no name entered");
    }
  } catch (Exception e) {
    println("Error showing dialog: " + e.getMessage());
    e.printStackTrace();
  }
}

void keyPressed() {
   if (key == 'z') {
      println("Press 'z' then click on map to position a city");
    }
    // code to accpet city name 
  if (cityNameRequired) {
    if (key == BACKSPACE && selectedCity.length() > 0) {
      selectedCity = selectedCity.substring(0, selectedCity.length() - 1);
    } 
    else if (key == ENTER || key == RETURN) {
      if (selectedCity.trim().length() > 0) {
        saveCityCoordinates(selectedCity.trim(), cityInputX, cityInputY);
      } else {
        println("City position not saved - no name entered");
      }
      cityNameRequired = false;
      selectedCity = "";
    } 
    else if ((key >= 'a' && key <= 'z') || (key >= 'A' && key <= 'Z') || 
             (key >= '0' && key <= '9') || key == ' ' || key == '-' || key == '\'') {
      // Capitalize the first letter when typing
      if (selectedCity.length() == 0) {
        // Capitalize the first letter of the city name
        selectedCity += Character.toUpperCase(key);
      } else {
        selectedCity += key;
      }
    }
    return; // Don't process other keys while entering city name
  }
  {
    if (key == 'a' || keyCode == LEFT) {
      rotationY += 0.05 ;
    }
    if (key == 'd' || keyCode == RIGHT) {
      rotationY -= 0.05;
    }
    if (key == 'w' || keyCode == UP) {
      rotationX -= 0.05;
    }
    if (key == 's' || keyCode == DOWN) {
      rotationX += 0.05;
    }

   }  
  // code to allow Year switching
  if (key == '1') { currentYear = 1991; println("year 1991 population"); }
  if (key == '2') { currentYear = 2001; println("year 2001 population"); }
  if (key == '3') { currentYear = 2011; println("year 2011 population"); }
    
 }

// load the city data function 
void loadCityData() {
  cities.clear();
  for (String region : regions.keySet()) {
    regions.get(region).clear();
  }
  
  Table table = loadTable("Data.csv", "header");
  if (table == null) {
    println("ERROR: Could not load Data.csv!");
    return;
  }

  // Check if X/Y columns exist; if not, create them with default values
  boolean hasX = tableHasColumn(table, "X");
  boolean hasY = tableHasColumn(table, "Y");
  
  for (TableRow row : table.rows()) {
    String name = row.getString("City");
    String region = row.getString("Region");
    int p91 = parsePopulation(row.getString("Census1991"));
    int p01 = parsePopulation(row.getString("Census2001"));
    int p11 = parsePopulation(row.getString("Census2011"));

    City city = new City(name, p91, p01, p11, region);

    // Sets the coordinates
    if (hasX && hasY) {
      city.x = row.getFloat("X");
      city.y = row.getFloat("Y");
    }
    cities.add(city);
  }
}

int parsePopulation(String popStr) {
  if (popStr == null || popStr.equals("") || popStr.equals("...")) {
    return 0;
  }
  popStr = popStr.replace("\"", "").replace(",", "");
  try {
    return Integer.parseInt(popStr);
  } catch (NumberFormatException e) {
    println("Error parsing population: " + popStr);
    return 0;
  }
}


class City {
  String name, region;
  int pop1991, pop2001, pop2011;
  float x, y;
  
  City(String n, int p91, int p01, int p11, String r) {
    name = n;
    pop1991 = p91;
    pop2001 = p01;
    pop2011 = p11;
    region = r;
  }
  
  int getPopulation(int year) {
    switch(year) {
      case 1991: return pop1991;
      case 2001: return pop2001;
      case 2011: return pop2011;
      default: return 0;
    }
  }
  
  boolean shouldDisplay(String filterRegion) {
    return filterRegion.equals("All") || region.equals(filterRegion);
  }
}
