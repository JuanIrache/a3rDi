//NOTE: This probably works with Windows only because of the Minoru 3D Webcam drivers. Needs MJPEG video drivers for video recording.

import ddf.minim.*; //Load minim to import and output sound
import ddf.minim.signals.*;
import ddf.minim.ugens.*;

import codeanticode.gsvideo.*; //import gsvideo to read both webcams (left and right from Minoru 3D webcam) and export video

GSPipeline pipelineA; //Variables that will read the webcams
GSPipeline pipelineB;

GSMovieMaker mmVideo; //Variable to save video
int fps = 25; //Match PAL video framerate, to record video properly no matter how long it takes to analyse a frame




GSPipeline pipelineExp;
 
Minim minim;

AudioInput in; //Audio recorder
AudioRecorder recorder;

boolean sketchFullScreen() {
    return false; //Full screen option
}

void setup()
{
  posarMida(); //set size based on fullscreen or window modes
  colorMode(HSB,255,255,255); //We will compare pixels based on Hue, Saturation and Brightness, not RGB
  ellipseMode(CORNER);
  frameRate(fps);
  background(0);
  smooth();
  
  String carregar[] = loadStrings("config.txt"); //load setup (saved from last time used)
  hAjust = int(carregar[0]);
  vAjust = int(carregar[1]);
  marge = float(carregar[2]);
  punts = int(carregar[3]);
  mostra = int(carregar[4]);
  ritme = float(carregar[5]);
  
  minim = new Minim(this);
  
  mesures(); //define size of measurements, based on framerate, detail on analysis, camera calibration, pauses...
  
  sortida = minim.getLineOut(Minim.STEREO, 2048); //Open audio out
  for (int i = 0; i <= 8 ; i++) {
    tri[i] = new SineWave(0, 0.0, sortida.sampleRate()); //create 9 audio waves, 0 will be left earphone, 8 will be right earphone, the rest are shades in between
    tri[i].portamento(10);
    sortida.addSignal(tri[i]); //add waves to audio output
  }
 
  pipelineA = new GSPipeline(this, "ksvideosrc device-index=2 ! decodebin2"); //Read webcams
  pipelineB = new GSPipeline(this, "ksvideosrc device-index=1 ! decodebin2");
  
  pipelineA.play(); //Start webcams
  pipelineB.play();   

}

void posarMida() { //set size based on fullscreen or window modes
  if (sketchFullScreen()) {
    size(displayWidth,displayHeight);
  } else {
    size(640,480);
  }
}

void mesures() {
  liniesSegon = ritme*((height - abs(vAjust))/punts); //lines that can  be scanned per second to avoid slowing down the framerate
  tempsLinia = 1000/liniesSegon; //time for each line
  mostraD = (int)(punts/mostra); //size of each measured area (including skipped pixels)
  finalX = 640-constrain(-hAjust,0,640)-(mostra*mostraD)+1; //last pixel to analyse (X)
  iniciY = constrain(vAjust,0,480); ////last pixel to analyse (Y)
  finalY = 480-constrain(-vAjust,0,480)-(mostra*mostraD); //last pixel to analyse (Y)
  multiWidth = (float)width/(640-abs(hAjust)); //amount to scale to display in fullscreen
  multiHeight = (float)height/(480-abs(vAjust));
}

float multiWidth; //amount to scale to display in fullscreen
float multiHeight;

int hAjust; //Calibration to set distant objects at the same horizontal position in both cameras
int vAjust;


float timeI; //Time spent each frame



void draw() {

 timeI = millis(); //Time spent each frame
   if (video == true) { //Decide actions to take
   video();
 }

  if (lazarillo == true) { //Main function: create 3D map and output sound
   lazarillo();
 } else
  if (canviador == true) { //switch between cameras to calibrate
   canviador();
 } else
 if (calibrar == true) { //show both cameras to calibrate
   calibrar();
 } else if (veure == true) { //show one or the other camera to calibrate
   veure();
 }
 //display framerate
 /*fill(0);
 rect(0,0,15,12);
 fill(255);
 text((int)frameRate,0,10);
 */
 if (outOff == true) { //switch off audio notiications (after pressing record or take picture)
   out.close();
   outOff = false;
 }
 
}

void lazarillo() { //Main function: create 3D map and output sound
  float timeLine = 0;
  while (millis() - timeI < (1000/fps) - timeLine ) { //decide whether there is enough time to analyse a new line and keep the framerate
    if (millis() >= timeLazarilloLine + tempsLinia) {
      timeLazarilloLine = millis();
      float time2 = millis();
      lazarilloLine(); //Analyse one line and output its sound
      timeLine = millis() - time2;
    }
  }

}

float simplificar(float f) { //Return usable numbers to avoid strange behavoirs (divide by zero, huge figures...)
  return constrain(f,0.000000001,999999999);
}



//modes

boolean video = false;
boolean canviador = false;
boolean calibrar = false;
boolean lazarillo = true;
boolean veure = false;
boolean veureA = true;

//customisable settings

int mostra; //Will store size of sample (matrix of pixels)
int punts; //Will determine how much an image has to be simplified before analysing it
float marge; //Will set the maximum difference between samples to determine whether we have found the corresponding sample in both images
float ritme; //Will store pace

//settings

float pausa = 150; //Pause between analysed frames
int soroll = 0; //allows to skip dark areas is noise is creating bad analysis.
int ampladaIteracions = 1; //distance between samples in the second image
int intents = 160/ampladaIteracions; //number of samples (attempts) in the second image
int mostraD; //size of each measured area (including skipped pixels)
int iniciX = 0; //First pixel to analyse (X)
int finalX; //last pixel to analyse(X)
int iniciY; //first pixel to analyse (Y)
int finalY; //last pixel to analyse (Y)
int timeLazarillo = millis(); //time spent per analysed frame
int timeLazarilloLine = millis(); //time spent per analysed line
float liniesSegon; //lines per second
float tempsLinia; //time per line

    
int ygrega = iniciY; //current line



PImage imatgeA = null; //Variables that will store the images to analyse
PImage imatgeB = null;

 
SineWave[] tri = new SineWave[9]; //9 Audio waves. allows panning
AudioOutput sortida; //audio output



float[] valors = new float[intents]; //will store the value of each "attempt" (difference between sample in image A and each tested sample in image B)
float[] perCH = new float[9];  //will save the determined distance to objects in 9 "columns", that will be panned to produce "3D sound environment"


void lazarilloLine() { //Analyse one line
  

  boolean skip = false;
  int ix = iniciX; //Start line
  int iteracions = 0; //Zero attempts so far
  perCH = new float[9]; //reset audio data

    if (millis() < timeLazarillo + pausa) { //if there is no time for the line, skip it
      skip = true;
    } else if (pipelineA.available() && pipelineB.available()) { //if cameras have captured a new frame
      if (video == false) { //if video is recording, image A has already been captured, no need to call the camera again
        pipelineA.read();
        imatgeA = pipelineA;
      } else {
        imatgeA = imatgeSave; //get the image from the video recorder
      }
      pipelineB.read(); //read camera B
      imatgeB = pipelineB;
    } else if (imatgeA == null || imatgeB == null) { //skip if we do not have one of the images
        skip = true;
    }
  
  if (skip == false) { //if everything is good

    if (ygrega<=finalY) { //and have not reached the end of the image
    fill(0,200);
    rect(0,ygrega*multiHeight,width,punts*multiHeight); //delete previous points in that area (line)
        while (ix < finalX ) { //analyse the entire line
          int indexActual = 0; //current attempt (sample from image B being analysed)
          boolean ignorarOrdre = false;
          int[] cadacolor = new int[mostra*mostra]; //matrix containing colour info of each pixel in the sample
          int iteracionsColorA = 0;
          for (int i=0; i<=mostra-1; i++) { //fill the matrix with colour data
            for (int j=0; j<=mostra-1; j++) {
              cadacolor[iteracionsColorA] = imatgeA.get(ix+(j*mostraD), ygrega+(i*mostraD));
              iteracionsColorA++;
            }
          }
          if (brightness(cadacolor[0])<soroll) { //skip pixel if it's darker than the noise treshold
            indexActual = 0;
          }
          else {
            int[] cadacolorB = new int[mostra*mostra]; //matrix containing colour info of each pixel in the sample from image B
            while (iteracions<intents) { //Attempts
              int iteracionsColorB = 0; //Attempted matches so far
              for (int i=0; i<=mostra-1; i++) { //fill the matrix with colour data from image B
                for (int j=0; j<=mostra-1 && (ix-hAjust+(iteracions*ampladaIteracions)+(mostra*mostraD)-1) <= width ; j++) {
                  cadacolorB[iteracionsColorB] = imatgeB.get(ix-hAjust+(iteracions*ampladaIteracions)+(j*mostraD), ygrega-vAjust+(i*mostraD));
                  iteracionsColorB++;
                }
              }
              float diferencia = 0; //measure how different the two samples are
              for (int i=0; i<=(mostra*mostra)-1 ; i++) {
                diferencia = diferencia + compararPunts(cadacolor[i],cadacolorB[i]); //difference pixel by pixel
              }
              valors[iteracions] = diferencia; //save "how different" sample B is from sample A
              if (diferencia<marge && ignorarOrdre == false) { //if the difference is smaller than the customisable benchmark
                indexActual = iteracions; //set horizontal distance as the currant number of attempts
                ignorarOrdre = true; //ignore sorting "quality" of attempts
                iteracions = intents; //pretend all the attempts have been made
              }
              iteracions++;
            }
            if (ignorarOrdre == false) { //find the smallest difference from all the attempts
              indexActual = 0;
              float valorActual = 500; //set a high difference value, just to make sure the condition is met the first time
              for(int i = 0;i<intents;i++){ //find the attempt with the smallest difference
                if (valors[i]<valorActual) {
                  valorActual = valors[i];
                  indexActual = i; //and assign its number as the horizontal distance between sample in image A and B
                }
              }
            }
          }
         ignorarOrdre = false;
          strokeWeight(0);
          float indexFinal = map(indexActual,0,intents,0,255); //map distance between samples to available colour values
          fill(indexFinal,255-(indexFinal/1.5),indexFinal);
          ellipse(ix*multiWidth,ygrega*multiHeight,punts*multiWidth,punts*multiHeight); //draw circles (closer= lighter+warmer)
          iteracions = 0;
          perCH[(int)map(ix,iniciX,finalX,1,9)] = perCH[(int)map(ix,iniciX,finalX,1,9)] + indexActual; //add distance to array that will determine the pitch (organised for panning)

          ix = ix+punts; //go to next sample from image A (same line)
        }
        ygrega = ygrega+punts; //go to next line of image A
        ix = 0; //start the line
        for (int i=0; i<8; i++) { //set audio waves
          float freq = map(perCH[i],0,(intents*(width/punts)/9),240,3000);
          tri[i].setPan(map(i,0,8,-1,1)); //panning: left, right, centre and shades
          tri[i].setFreq(freq); //frequency= closer areas have higher pitch
          tri[i].setAmp(0.3); //amplitude (to turn on the wave)
        } 
    } else { //if image is complete
      ygrega = iniciY; //go to next image
      for (int i=0; i<8; i++) {
          tri[i].setAmp(0.0);  //turn off waves
      }
      timeLazarillo = millis(); //reset time of frame
    }
}          
}

float compararPunts(color a, color b) { //compare pixels
  float comparacio = ((abs(1-(simplificar(brightness(a))/simplificar(brightness(b)))))/(mostra*mostra)*0.8); //brightness determines 80% of the comparison result
  comparacio = comparacio + ((abs(1-(simplificar(hue(a))/simplificar(hue(b)))))/(mostra*mostra)*0.13); //hue determines 13% of the comparison result
  comparacio = comparacio + ((abs(1-(simplificar(saturation(a))/simplificar(saturation(b)))))/(mostra*mostra)*0.07); //saturation determines 7% of the comparison result
  return comparacio;
}

AudioOutput out; //audio feedback when recording or taking a photo
Oscil wave;
boolean outOff = false;

void fotos() {
      if (imatgeA != null) {
        wave = new Oscil( 800, 1, Waves.TRIANGLE ); //provide audio feedback
        out = minim.getLineOut();
        wave.patch( out );
        outOff = true; //tell the sketch to turn this wave off in the next cycle
        
       image(imatgeA,0,0); //display image
       saveFrame("/photos/"+year()+"."+month()+"."+day()+"."+hour()+"."+minute()+"."+second()+"####"+".jpg"); //save displayed image in the /fotos folder, as a jpg
      }
}



PImage imatgeSave = null; //will store the image captured for the video recorder


int comptarFrames = 0; //variables to find out the real framerate provided by the webcam
int tempsActual = millis()/1000;

void video() { //record video

  if (pipelineA.available()) { //If camera A has a new frame
       pipelineA.read(); //read camera A
       imatgeSave = pipelineA; 

      if (tempsActual == millis()/1000) { //count frames per second to detect low framerrates from the camera
        comptarFrames++;
      } else {
        println("frameRate Video: "+comptarFrames);
        comptarFrames = 1;
      }
      tempsActual = millis()/1000;

  }
  if (imatgeSave != null) { //Add image to video
       image(imatgeSave,0,0);
       loadPixels();
       mmVideo.addFrame(pixels);
  }
}

void calibrar() { //See both images at the same time. useful for calibration (align images)
  if (pipelineA.available() && pipelineB.available()) { //if cameras have a new frame
    pipelineA.read();
    PImage imatgeA = pipelineA; // read them and show them with alpha
    pipelineB.read();
    PImage imatgeB = pipelineB;
    image(imatgeA,0,0);
    tint(255,127);
    image(imatgeB,hAjust,vAjust);
    noTint();
  }
}

boolean canviat = false; //switches between cams

void canviador() { //show a different camera each frame. useful for calibration (aligning images)
    if (pipelineA.available() && pipelineB.available()) {
    pipelineA.read();
    PImage imatgeA = pipelineA;
    pipelineB.read();
    PImage imatgeB = pipelineB;
        if (canviat == false) {
            image(imatgeA,0,0);
            canviat = true;
          }
          else {
            image(imatgeB,hAjust,vAjust);
            canviat = false;       
          }
    }
}

void veure() { //see one of the cameras. useful to set up the camera: brightness, contrast, etc.
  if (veureA == true) {
    if (pipelineA.available()) {
    pipelineA.read();
    PImage imatgeA = pipelineA;
    image(imatgeA,0,0);
    }
  } else { //show the other camera
    if (pipelineB.available()) {
    pipelineB.read();
    PImage imatgeB = pipelineB;
    image(imatgeB,0,0);
    }
  }
}

void videoButton() { //record video button pressed, either from the keyboard or the mouse
if (video == true) { //if video is on, turn it off
      wave = new Oscil( 400, 1, Waves.TRIANGLE ); //sound feedback, video off
      out = minim.getLineOut();
      wave.patch( out );
      outOff = true; //will turn this wave off on the next frame
      
      video = false; //turn off video

      mmVideo.finish(); //close video file
      
      recorder.endRecord(); //close and save audio recording
      recorder.save();
    } else { //turn video on if it was off
      wave = new Oscil( 1200, 1, Waves.TRIANGLE ); //provide confirmation feedback
      out = minim.getLineOut();
      wave.patch( out );
      outOff = true; //will turn this wave off on the next frame
      
      video = true; //turn video on
      
      mmVideo = new GSMovieMaker(this, width, height, "/video/"+year()+"."+month()+"."+day()+"."+hour()+"."+minute()+"."+second()+".avi", GSMovieMaker.MJPEG, GSMovieMaker.BEST, fps);
      mmVideo.setQueueSize(50, 10); //create video file
      mmVideo.start();
      
      in = minim.getLineIn(); //record audio from webcam
      recorder = minim.createRecorder(in, "/video/"+year()+"."+month()+"."+day()+"."+hour()+"."+minute()+"."+second()+".wav", true);
      
      recorder.beginRecord();
  
    }
}

void lazarilloOff() { //turn off main mode
      for (int i=0; i<8; i++) { //turn off sounds
          tri[i].setAmp(0.0);
      }
      lazarillo = false; //turn off 3D mapping and sound
}

void keyPressed() { //keyboard controls (calibration, testing...)
  if (key == 'p' || key == 'P') { //modes
    fotos();
  } else if (key == 'v' || key == 'V') {
    videoButton();
  } else if (key == 'c' || key == 'C') {
    if (canviador == true) {
      canviador = false;
      veure = false;
      lazarillo = true;
    } else {
      canviador = true;
      veure = false;
      lazarilloOff();
      calibrar = false;
    }
  } else if (key == 'k' || key == 'K') {
    if (calibrar == true) {
      calibrar = false;
      veure = false;
      lazarillo = true;
    } else {
      calibrar = true;
      veure = false;
      lazarilloOff();
      canviador = false;
    }
  } else if (key == 's' || key == 'S') {
    if (veure == true) {
      veure = false;
      lazarillo = true;
    } else {
      veure = true;
      calibrar = false;
      lazarilloOff();
      canviador = false;
    }
  } else if (key == 'a' || key == 'A') {
    if (veure == true) {
      if (veureA == true) {
        veureA = false;
      }  else {
        veureA = true;
      }
    }
  }  else if (key == 'l' || key == 'L') {
    if (lazarillo == true) {
      lazarilloOff();
    } else {
      veure = false;
      calibrar = false;
      canviador = false;
      lazarillo = true;
    }
  } else if (key == '7') { //customise variables
    marge = constrain(marge-0.01,0,1);
    guardar();
    println("marge: "+marge);
  } else if (key == '9') {
    marge = constrain(marge+0.01,0,1);
    guardar();
    println("marge: "+marge);
  } else if (key == '4') {
    punts = constrain(punts+1,1,100);
    guardar();
    println("punts: "+punts);
    mesures();
  } else if (key == '6') {
    punts = constrain(punts-1,1,100);
    guardar();
    println("punts: "+punts);
    mesures();
  } else if (key == '1') {
    mostra = constrain(mostra-1,1,7);
    guardar();
    println("mostra: "+mostra);
    mesures();
  } else if (key == '3') {
    mostra = constrain(mostra+1,1,7);
    guardar();
    println("mostra: "+mostra);
    mesures();
  } else if (key == '0') {
    ritme = constrain(ritme-1,1,50);
    guardar();
    println("ritme: "+ritme);
    mesures();
  } else if (key == '.') {
    ritme = constrain(ritme+1,1,50);
    guardar();
    println("ritme: "+ritme);
    mesures();
  }
  if (key == CODED) { //image alignment
    if (keyCode == DOWN) {
      vAjust++;
      println("vAjust: "+vAjust);
    } else if (keyCode == UP) {
      vAjust--;
      println("vAjust: "+vAjust);
    } else if (keyCode == RIGHT) {
      hAjust++;
      println("hAjust: "+hAjust);
    } else if (keyCode == LEFT) {
      hAjust--;
      println("hAjust: "+hAjust);
    } 
   guardar(); //save custom variables after customising
   mesures(); //recalculate size of everything based on new custom variables
  }
}

void mousePressed() { //mouse triggers photos and video recording
  if (mouseButton == LEFT) {
    videoButton();
  }
  if (mouseButton == RIGHT) {
    fotos();
  }
 
}

void guardar() { //store custom settings in a txt file
  String[] config = new String[10];
  config[0] = str(hAjust);
  config[1] = str(vAjust);
  config[2] = str(marge);
  config[3] = str(punts);
  config[4] = str(mostra);
  config[5] = str(ritme);
  saveStrings("config.txt",config);
}

void stop() { //close audio outputs, minim and program
  out.close();
  sortida.close();
  minim.stop();
  super.stop();
}


