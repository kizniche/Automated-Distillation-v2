
//   Stillduino v2
//   Copyright 2011 Kyle Gabriel

//   For the automation of a water distillation machine with the use of relays
//   controlling power to a condenser fan, heating element, and LCD backlight.
//   Input is gathered from a push-button rotary encoder.
//   Feedback is displayed as control menus or the current status on a 16x2 LCD.

//   This program is free software: you can redistribute it and/or modify
//   it under the terms of the GNU General Public License as published by
//   the Free Software Foundation, either version 3 of the License, or
//   (at your option) any later version.

//   This program is distributed in the hope that it will be useful,
//   but WITHOUT ANY WARRANTY; without even the implied warranty of
//   MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
//   GNU General Public License for more details.

//   You should have received a copy of the GNU General Public License
//   along with this program.  If not, see <http://www.gnu.org/licenses/>.

int debug = 0;

#include <avr/sleep.h>      //  Changes arduino's power mode
#include <LiquidCrystal.h>  //  Draws text on a 16x2 LCD
#include <avr/pgmspace.h>   //  Write quotes to program space
#include <EEPROM.h>         //  Reads/Writes EEPROM
#include "EEPROMAnything.h" //  Keeps track of how much water has been distilled
#include <QuadEncoder.h>    //  Detects change in the rotary encoder position
                            //  QuadEncoder.h by Pedro Rodrigues (medecau@gmail.com), January 2010

LiquidCrystal lcd(8,9,10,11,12,13);  //  Pins for LCD output
QuadEncoder qe(4,5);                 //  Pins for rotary encoder
int buttonwakePin = 2;               //  Pin for rotary encoder button
int lcd_RelayPin = 3;                //  Pin for LCD backlight relay
int heat_RelayPin = 6;               //  Pin for heating coil relay
int fan_RelayPin = 7;                //  Pin for condenser fan relay

int qe1Move = 0;     //  Rotary encoder position returned by QuadEncoder.h
int wake = 1;        //  wakeUpNow() to be executed once at boot, once upon wake
int relays_on = 0;   //  Signal to turn the relays on or off
int rotary = 1;      //  Stores the current rotary dial position
int rotaryLast = 1;  //  Stores the last rotary dial position

int saveVolume = 0;  //  After successful distillation, is signal to write filterVolume to EEPROM
int volume;          //  Integer of water.filterVolume that is passed to functions
long tVolume;        //  Stores the total volume distilled. Must be reset with looped EEPROM.write()

static unsigned long countdown_timer;  //  Countdown to turn unit off
static unsigned long countup_timer;    //  Countdown to turn unit on
static unsigned long relay_timer;      //  = lWaitMillis, for timing in relay_control()
static unsigned long lWaitMillis;      //  Handle millis() rollover for long timing

float tts = 0;            //  Time until distillation starts, in increments of 30 minutes
float liters[] = {        //  Store pre-defined volumes for menu display
  0, 3.0, 2.5, 1.5, 1.0};  

int menu[] = {            //  LCD menu [menu#, volume of water, timer, confirm ]
  1, 1, 1, 1 };

long preset[5][2] = {     // Fill boiling chamber with cold water to above the heating element,
  {                       // then add 1, 1.5, 2.5, or 3 liters of water to the boiling chamber.
    0, 0     }            // This amount will be distilled, leaving the heating element submerged.
  ,{                      // {turn fan on after, turn heater & fan off after} in miliseconds
    1800000, 12840000  }  // 3 liters
  ,{
    1500000, 11000000   } // 2.5 liters
  ,{
    900000, 6300000   }   // 1.5 liters
  ,{
    700000, 5900000   }   // 1 liter
};

/***********************************************************************************************
 *** Since only 1k mem is available to variables, long strings must be put into program memory
 ***********************************************************************************************/

prog_char string_0[] PROGMEM = "Better than a thousand hollow words, is one word that brings peace. -Buddha/";
prog_char string_1[] PROGMEM = "Tao in the world is like a river flowing home to the sea. -Tao Te Ching/";
prog_char string_2[] PROGMEM = "Learn from yesterday, live for today, hope for tomorrow./";
prog_char string_3[] PROGMEM = "The artist finds a greater pleasure in painting than in having a completed picture. -Seneca/";
prog_char string_4[] PROGMEM = "Playing it safe is the most popular way to fail. -Elliott Smith/";
prog_char string_5[] PROGMEM = "Failure defeats losers, failure inspires winners. -Robert T. Kiyosaki/";
prog_char string_6[] PROGMEM = "The foot feels the foot when it feels the ground. -Buddha/";
prog_char string_7[] PROGMEM = "Don't worry, be happy. -McFerrin/";
prog_char string_8[] PROGMEM = "The only rule is it begins. Happy, happy, oh my friend. -Phish/";
prog_char string_9[] PROGMEM = "You will not do incredible things without an incredible dream. -John Eliot/";
prog_char string_10[] PROGMEM = "Fill your mind with compassion. -Buddha/";
prog_char string_11[] PROGMEM = "To live a pure, unselfish life, one must count nothing as one's own in the midst of abundance./";
prog_char string_12[] PROGMEM = "Do not dwell in the past, do not dream of Future, concentrate the mind on the present moment. -Buddha/";
prog_char string_13[] PROGMEM = "A jug fills drop by drop. -Buddha/";
prog_char string_14[] PROGMEM = "Hello, Human.                NEED Water?/";
prog_char string_15[] PROGMEM = "It is better to travel well than to arrive. -Buddha/";
prog_char string_16[] PROGMEM = "Those who are free of resentful thoughts surely find peace./";
prog_char string_17[] PROGMEM = "Virtue is persecuted more by the wicked than it is loved by the good./";
prog_char string_18[] PROGMEM = "Do not speak- unless it improves on silence./";
prog_char string_19[] PROGMEM = "Love and compassion are necessities, not luxuries. Without them, humanity cannot survive. -14th Dalai Lama/";
prog_char string_20[] PROGMEM = "You must be the change you wish to see in the world. -Gandhi/";
prog_char string_21[] PROGMEM = "Anyone who has never made a mistake has never tried anything new. -Einstein/";
prog_char string_22[] PROGMEM = "You don't need a weatherman to know which way the wind blows. -Bob Dylan/";
prog_char string_23[] PROGMEM = "My life is my message. -Gandhi/";
prog_char string_24[] PROGMEM = "Everything that irritates us about others can lead us to an understanding of ourselves. -Carl Jung/";
prog_char string_25[] PROGMEM = "There are only two mistakes one can make along the road to truth; not going all the way, and not starting. -Buddha/";
prog_char string_26[] PROGMEM = "You, yourself, as much as anybody in the entire universe, deserve your love and affection. -Buddha/";
prog_char string_27[] PROGMEM = "Everything has beauty, but not everyone sees it. -Confucius/";
prog_char string_28[] PROGMEM = "Learn as if you were going to live forever. Live as if you were going to die tomorrow. -Gandhi/";
prog_char string_29[] PROGMEM = "The most common way people give up their power is by thinking they don't have any. -Alice Walker/";
prog_char string_30[] PROGMEM = "That which does not kill us makes us stronger. -Nietzsche/";
prog_char string_31[] PROGMEM = "When you look into an abyss, the abyss also looks into you. -Nietzche/";
prog_char string_32[] PROGMEM = "It is not because things are difficult that we do not dare, it is because we do not dare that they are difficult. -Seneca/";
prog_char string_33[] PROGMEM = "As long as you live, keep learning how to live. -Seneca/";
prog_char string_34[] PROGMEM = "Ahh, Earth Day, the only day of the year where being able to hacky-sack will get you laid. -Jon Stewart/";
prog_char string_35[] PROGMEM = "A short saying often contains much wisdom. -Sophocles/";
prog_char string_36[] PROGMEM = "Know thyself. -Socrates/";
prog_char string_37[] PROGMEM = "Nothing gold can stay. -Robert Frost/";
prog_char string_38[] PROGMEM = "No great thing is created suddenly. -Epictetus/";
prog_char string_39[] PROGMEM = "Well done is better than well said. -Benjamin Franklin/";
prog_char string_40[] PROGMEM = "Fame was like a drug. But what was even more like a drug were the drugs. -Homer Simpson/";
prog_char string_41[] PROGMEM = "Weaseling out of things is important to learn. It’s what separates us from the animals... except the weasel. -Homer Simpson/";
prog_char string_42[] PROGMEM = "Maybe, just once, someone will call me 'Sir' without adding, 'You're making a scene.' -Homer Simpson/";
prog_char string_43[] PROGMEM = "Donuts. Is there anything they can't do? -Homer Simpson/";
prog_char string_44[] PROGMEM = "You can't wake a person who is pretending to be asleep. -Navajo Proverb/";
prog_char string_45[] PROGMEM = "Even a clock that does not work is right twice a day. -Polish Proverb/";
prog_char string_46[] PROGMEM = "Sometimes it's necessary to go a long distance out of the way in order to come back a short distance correctly. -Edward Albee/";
prog_char string_47[] PROGMEM = "When the student is ready, the master appears. -Buddhist Proverb/";
prog_char string_48[] PROGMEM = "Before enlightenment- chop wood, carry water. After enlightenment- chop wood, carry water. -Zen Buddhist Proverb/";
prog_char string_49[] PROGMEM = "Many men go fishing all of their lives without knowing that it is not fish they are after. -Henry David Thoreau/";
prog_char string_50[] PROGMEM = "If you think you're free, there's no escape possible. -Ram Dass/";
prog_char string_51[] PROGMEM = "Only that in you which is me can hear what I'm saying. -Ram Dass/";
prog_char string_52[] PROGMEM = "If you chase two rabbits, you will not catch either one. -Russian Proverb/";
prog_char string_53[] PROGMEM = "The obstacle is the path. -Zen Proverb/";
prog_char string_54[] PROGMEM = "Sometimes the questions are complicated and the answers are simple. -Dr Seuss/";
prog_char string_55[] PROGMEM = "Things are entirely what they appear to be and behind them... there is nothing. -Sartre/";
prog_char string_56[] PROGMEM = "Who is more foolish, the child afraid of the dark or the man afraid of the light? -Maurice Freehill/";
prog_char string_57[] PROGMEM = "Eggs cannot be unscrambled. -American Proverb/";
prog_char string_58[] PROGMEM = "The charm of history and its enigmatic lesson consist in the fact that, from age to age, nothing changes and yet everything is completely different. -Aldous Huxley/";
prog_char string_59[] PROGMEM = "A wise man can see more from the bottom of a well than a fool can from a mountain top./";
prog_char string_60[] PROGMEM = "The only Zen you can find on the tops of mountains is the Zen you bring up there. -Robert Pirsig/";
prog_char string_61[] PROGMEM = "A stumble may prevent a fall. -English Proverb/";
prog_char string_62[] PROGMEM = "The greater danger for most of us lies not in setting our aim too high and falling short; but in setting our aim too low, and achieving our mark. -Michelangelo/";
prog_char string_63[] PROGMEM = "Do not seek to follow in the footsteps of the wise. Seek what they sought. -Matsuo Basho/";
prog_char string_64[] PROGMEM = "Life is a whim of several billion cells to be you for a while./";
prog_char string_65[] PROGMEM = "Don't look where you fall, but where you slipped. -African Proverb/";
prog_char string_66[] PROGMEM = "Dig the well before you are thirsty. -Chinese Proverb/";
prog_char string_67[] PROGMEM = "When you throw dirt, you lose ground. -Texan Proverb/";

PROGMEM const char *quote[] = // Create a 2-dimensional array with the above strings
{   
  string_0,
  string_1,
  string_2,
  string_3,
  string_4,
  string_5,
  string_6,
  string_7,
  string_8,
  string_9,
  string_10,
  string_11,
  string_12,
  string_13,
  string_14,
  string_15,
  string_16,
  string_17,
  string_18,
  string_19,
  string_20,
  string_21,
  string_22,
  string_23,
  string_24,
  string_25,
  string_26,
  string_27,
  string_28,
  string_29,
  string_30,
  string_31,
  string_32,
  string_33,
  string_34,
  string_35,
  string_36,
  string_37,
  string_38,
  string_39,
  string_40,
  string_41,
  string_42,
  string_43,
  string_44,
  string_45,
  string_46,
  string_47,
  string_48,
  string_49,
  string_50,
  string_51,
  string_52,
  string_53,
  string_54,
  string_55,
  string_56,
  string_57,
  string_58,
  string_59,
  string_60,
  string_61,
  string_62,
  string_63,
  string_64,
  string_65,
  string_66,
  string_67,
};

char buffer[200]; // Set the maximum length of the progmem strings (remember to also change pre_marquee)

/***********************************************************************************************
 *** Check for input from the rotary encoder (button press/knob turn), then take action.
 ***********************************************************************************************/

void ReadEncoder()
{
  if ((long)(millis() - lWaitMillis) >= 0) lWaitMillis += 1000;  // prevent time rollover
  if (qe1Move == '>' || qe1Move == '<') // Update rotary if turn detected
  {
    if (qe1Move == '<' && rotary <= 6)
    {
      if (rotary < 6) rotary++;
      else rotary = 1;
    } 
    else if (qe1Move == '>' && rotary >= 1)
    {
      if (rotary > 1) rotary--;
      else rotary = 6;
    }
    if (debug) status();       // Print status if debug is 1
    display_LCD();
  }

  if (rotaryLast != rotary && menu[0] != 4) // If rotary changes, set mode & update LCD
  {
    if (menu[0] == 3)
    {
      if (menu[3] == 2) menu[3] = 1;
      else if (menu[3] == 1) menu[3] = 2;
    } 
    else if (menu[0] == 2)
    {
      if (qe1Move == '>')
      { 
        tts = tts + 30;
        menu[2] = 0;
      }
      else if (tts > 0)
      { 
        tts = tts - 30;
        if (tts == 0) menu[2] = 1;
      }
    } 
    else if (menu[0] == 1)
    {
      menu[1] = rotary; 
    }
    rotaryLast = rotary;
    display_LCD();
  }

  if (digitalRead(buttonwakePin) == LOW)
  {
    while (digitalRead(buttonwakePin) == LOW) // Wait for button to go back to HIGH to continue
    {                                         // Prevents weird results if the button is held down
      delay(1);
    }
    if (menu[0] == 1)
    {
      if (menu[1] == 5)
      {
        saveVolume = 2;
        rotary = 1;
        display_LCD();
      } 
      else if (menu[1] == 6)
      {
        menu[0] = 1;
        menu[1] = 1;
        menu[2] = 1;
        rotary = 1;
        tts = 0;
        delay(100);
        PowerDown();
      }
      else
      {
        menu[0] = 2;
        display_LCD();
      }
    }
    else if (menu[0] == 2)
    {
      menu[0] = 3;
      menu[2] = 1;
      display_LCD();
    }
    else if (menu[0] == 3)
    {
      if (menu[3] == 1)
      {
        menu[0] = 4;
        relays_on = 1;
        countup_timer = (tts*60000) + lWaitMillis;
        relay_timer = lWaitMillis;
      }
      else if (menu[3] == 2)
      {
        menu[0] = 1;
        menu[1] = 1;
        menu[2] = 1;
        menu[3] = 1;
        tts = 0;
        relays_on = 0;
        rotary = 1;
      }
      display_LCD();
    }
    else if (menu[0] == 4)
    {
      menu[0] = 1;
      menu[1] = 1;
      menu[2] = 1;
      menu[3] = 1;
      relays_on = 0;
      tts = 0;
      rotary = 1;
      display_LCD();
    }
  }
}

/***********************************************************************************************
 *** Display the current menu on the LCD.
 ***********************************************************************************************/

void display_LCD()
{
  switch (menu[0])
  {
  case 1:             // Receive input of quantity of water to distill
    lcd.clear();
    lcd.setCursor(0,0);
    switch (menu[1])
    {
    case 1:
      lcd.print("Amount of water:");
      lcd.setCursor(3,1);
      lcd.print("3.0 Liters");
      break;
    case 2:
      lcd.print("Amount of water:");
      lcd.setCursor(3,1);
      lcd.print("2.5 Liters");
      break;
    case 3:
      lcd.print("Amount of water:");
      lcd.setCursor(3,1);
      lcd.print("1.5 Liters");
      break;
    case 4:
      lcd.print("Amount of water:");
      lcd.setCursor(3,1);
      lcd.print("1.0 Liters");
      break;
    case 5:
      lcd.print("    L Distilled");
      lcd.setCursor(0,0);
      lcd.print(volume);
      lcd.setCursor(0,1);
      lcd.print(" PRESS TO RESET");
      break;
    case 6:
      lcd.print("    PRESS TO");
      lcd.setCursor(0,1);
      lcd.print("   POWER DOWN");
      break;
    }
    break;
  case 2:             // Receive input of when to start distilling
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print(" Time to Start?");
    switch (menu[2])
    {
    case 1:
      lcd.setCursor(7,1);
      lcd.print("NOW");
      break;
    default:
      lcd.setCursor(3,1);
      lcd.print((tts/60),1);
      lcd.setCursor(8,1);
      lcd.print("Hours");
    }
    break;
  case 3:             // Receive input to confirm the last two options
    lcd.clear();
    if (tts != 0)
    {
      lcd.setCursor(4,0);
      lcd.print("L in     Hrs");
      lcd.setCursor(0,0);
      lcd.print(liters[menu[1]],1);
      lcd.setCursor(9,0);
      lcd.print((tts/60),1);
    }
    else
    {
      lcd.setCursor(7,0);
      lcd.print("L, NOW");
      lcd.setCursor(3,0);
      lcd.print(liters[menu[1]],1);
    }
    lcd.setCursor(0, 1);
    lcd.print("  CONFIRM:");
    switch (menu[3])
    {
    case 1:
      lcd.setCursor(11,1);
      lcd.print("YES");
      break;
    case 2:
      lcd.setCursor(11,1);
      lcd.print("NO ");
      break;
    }
    break;
  case 4:             // Display quantity of water and countdown to start or finish
    if (relays_on)
    {
      lcd.clear();
      if (countup_timer > lWaitMillis)
      {
        lcd.setCursor(4,0);
        lcd.print("Min To Start");
        lcd.setCursor(0,0);
        lcd.print((((countup_timer-lWaitMillis))/60000));
        lcd.setCursor(0,1);
        lcd.print("    L PrsToCancl");
        lcd.setCursor(0,1);
        lcd.print(liters[menu[1]],1);
      } 
      else
      {
        lcd.setCursor(0,0);
        lcd.print("    L     MinRem");
        lcd.setCursor(0,0);
        lcd.print(liters[menu[1]],1);
        lcd.setCursor(6,0);
        lcd.print(((preset[menu[1]][1]-(lWaitMillis-relay_timer))/60000)+1);
        lcd.setCursor(0,1);
        lcd.print("PRESS TO CANCEL!");
      }
    }
    else  // When finished, display "Cooling Down" warning for 30 minutes, then sleep
    {
      if (((lWaitMillis-relay_timer)-preset[menu[1]][1]) < 1800000)
      {
        if (rotary)
        {
          lcd.clear();
          lcd.setCursor(0,0);
          lcd.print("-   FINISHED   -");
          lcd.setCursor(0, 1);
          lcd.print("! CAUTION, HOT !");
          rotary = 0;
        }
        else if (!rotary)
        {
          lcd.clear();
          lcd.setCursor(0,0);
          lcd.print("!   FINISHED   !");
          lcd.setCursor(0, 1);
          lcd.print("- CAUTION, HOT -");
          rotary = 1;
        }
      }
      else {
        menu[0] = 1;
        menu[1] = 1;
        menu[2] = 1;
        menu[3] = 1;
        rotary = 1;
        delay(100);
        PowerDown();
      }
    }
    break;
  }
}

/***********************************************************************************************
 *** Determine if fan and heat relay should be on or off / turn each on or off
 ***********************************************************************************************/

void relay_control()
{
  if (relays_on == 1)
  {
    if (countup_timer > lWaitMillis)
    { 
      relay_timer = lWaitMillis; 
    }
    else
    {
      if (lWaitMillis-relay_timer >= preset[menu[1]][0]) // Turn fan on after water is heated (saves power)
      {
        digitalWrite(fan_RelayPin, HIGH);
      }
      if (lWaitMillis-relay_timer > 0) // Turn heater on after relay_timer is set
      {
        digitalWrite(heat_RelayPin, HIGH);
      }
      if (lWaitMillis-relay_timer > preset[menu[1]][1]) // Turn all pins off after time has passed to distil selected volume
      {
        digitalWrite(heat_RelayPin, LOW);
        digitalWrite(fan_RelayPin, LOW);
        relays_on = 0;
        saveVolume = 1;
      }
    }
  }
  else // Power both relays OFF if relays_on is not set to 1
  {
    digitalWrite(heat_RelayPin, LOW);
    digitalWrite(fan_RelayPin, LOW);
  }
}

/***********************************************************************************************
 *** Put the arduino to sleep until the button is pressed
 ***********************************************************************************************/

void PowerDown()
{
  lcd.clear();
  digitalWrite(lcd_RelayPin, LOW);
  set_sleep_mode(SLEEP_MODE_PWR_DOWN); 
  sleep_enable();                     // Enable the sleep bit in the mcucr register
  attachInterrupt(0,wakeUpNow, LOW);  // Use interrupt 0 (pin 2) and wake when pin 2 = LOW 
  sleep_mode();                       // Put to sleep.
  // Where program continues after waking...
  sleep_disable();                    // First thing after waking from sleep, disable sleep
  detachInterrupt(0);                 // disables interrupt 0 on pin 2 so button can be used
  digitalWrite(lcd_RelayPin, HIGH);
  wake = 1;
}

/***********************************************************************************************
 *** 
 ***********************************************************************************************/

void wakeUpNow()
{ // Run when plugged in and after waking from sleep
  while (digitalRead(buttonwakePin) == LOW)
  {
    delay(1);
  }
  lcd.clear();
  lcd.setCursor(0,0);
  lcd.print("   One  Moment");
  lcd.setCursor(0,1);
  lcd.print("  Testing  Fan");
  digitalWrite(fan_RelayPin, HIGH);   // Fan test start: turn fan on for a few seconds
  delay(4000);
  rand_quote();
  digitalWrite(fan_RelayPin, LOW);    // Fan test 
  
  if (volume >= 113) // If more than 113 liters have been distilled with the current filter,
  {                  // notify that it should be changed and the counter reset.
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print(">113 L Distilled");
    lcd.setCursor(0,1);
    lcd.print(" Replace Filter");
    delay(3000);
    lcd.setCursor(0,1);
    lcd.print("& Reset Counter");
    delay(3000);
    lcd.clear();
    lcd.setCursor(0,0);
    lcd.print("    Press to");
    lcd.setCursor(0,1);
    lcd.print("  Acknowledge.");
    int confirm = 1;
    while (confirm) // Must press to confirm the filter needs changing before continuing
    {
      while (digitalRead(buttonwakePin) == LOW)
      {
        delay(1);
        confirm = 0;
      }
    }
  }
  display_LCD();
}

/***********************************************************************************************
 *** Collect random number, then select and display that quote
 ***********************************************************************************************/

void rand_quote()
{
  int quoteNum;
  unsigned long seed=seedOut(31);
  randomSeed(seed); // The more random data for the seed
  quoteNum = random(0,68);
  strcpy_P(buffer, (char*)pgm_read_word(&(quote[quoteNum])));  // Copy quote from program memory to buffer[]
  int post;
  char pre_marq[216];
  for (post=0;post<201;post++)  // Find how long the quote is
  {
    if (buffer[post] == '/') break;
    else pre_marq[post] = buffer[post];
  }
  char marquee[post+16];
  for (int i=0;i<post+16;i++) // Add 16 spaces to the beginning of the quote
  {
    if (i<16) marquee[i] = ' ';
    else
    {
      marquee[i] = buffer[i-16];
    }
  }
  int end = 0;
  int e = 0;
  for (int i=0;i<post+18;i++) // Scroll the quote across the LCD from right to left, inserting 16
  {                           // spaces to the right of the quote before finishing the function
    if (end) e++;
    if (e > 16) break;
    lcd.setCursor(0,0);
    for (int j=0;j<16;j++)
    {
      if (marquee[j+i] == '/')
      {
        end=1;
      }
      if (j+i>post+15) lcd.print(' ');
      else lcd.print(marquee[j+i]);
    }
    delay(200);
    if (digitalRead(buttonwakePin) == LOW) // Button press skips the display of a quote
    {
      while (digitalRead(buttonwakePin) == LOW)
      {
        delay(1);
      }
      i = post+18;
    }
  }
}

/***********************************************************************************************
 *** Random by David Pankhurst, http://www.utopiamechanicus.com/77/better-arduino-random-numbers
 ***********************************************************************************************/

unsigned long seedOut(unsigned int noOfBits) 
{
  unsigned long seed=0, limit=99;
  int bit0=0, bit1=0;
  while (noOfBits--)
  {
    for (int i=0; i<limit; ++i)
    {
      bit0=analogRead(0)&1;
      bit1=analogRead(0)&1;
      if (bit1 != bit0) break;
    }
    seed = (seed<<1) | bit1;
  }
  return seed; // return value with 'noOfBits' random bits set
}

/***********************************************************************************************
 *** Print status for debugging/logging when debug=1 
 ***********************************************************************************************/

void status()
{
  Serial.print("  filterVolume: ");
  Serial.print(volume);
  Serial.print("  totalVolume: ");
  Serial.print(tVolume);
  Serial.print(" relay_timer: ");
  Serial.print(relay_timer);
  Serial.print("  rotary: ");
  Serial.print(rotary);
  Serial.print("  Move: ");
  Serial.print(char(qe1Move));
  Serial.print("  lWitMillis: ");
  Serial.print(lWaitMillis);
  Serial.print("  Mode: ");
  Serial.print(menu[1]);
  Serial.print("  R1Heat: ");
  Serial.print(digitalRead(heat_RelayPin));
  Serial.print(", R2Fan:");
  Serial.print(digitalRead(fan_RelayPin));
  Serial.print("  R3LCD: ");
  Serial.print(digitalRead(lcd_RelayPin));
  Serial.print("  Fan on > ");
  Serial.print(preset[menu[1]][0]);
  Serial.print(" sec  Both off > ");
  Serial.print(preset[menu[1]][1]);
  Serial.print(" sec.");
  Serial.println();
}

struct config_t // Variables read/written to EEPROM
{
    float filterVolume;
    long totalVolume;
} water;

void setup()
{
  EEPROM_readAnything(0, water);      // Read filterVolume from EEPROM
  if (debug)                          // Bring up serial communication if debugging
  {
    Serial.begin(9600);
    Serial.println("Ready to begin");
  }
  lWaitMillis = millis() + 1000;      // millis() rollover protection initial setup
  lcd.begin(16,2);                    // Configure LCD as 16x2 display
  pinMode(lcd_RelayPin, OUTPUT);      // Configure LCD relay pin
  pinMode(fan_RelayPin, OUTPUT);      // configure fan relay pin
  pinMode(heat_RelayPin, OUTPUT);     // configure heating coil relay pin
  pinMode(buttonwakePin, INPUT);      // Configure wakeup button
  digitalWrite(lcd_RelayPin, HIGH);   // Turn LCD backlight ON
}

void loop()
{
  EEPROM_readAnything(0, water);
  volume = water.filterVolume;  // for global variable recognition
  tVolume = water.totalVolume;  // holds volume total for life of distiller
  
  if (wake) wakeUpNow();        // Run once per power up
  wake = 0;

  qe1Move = qe.hb();            // Monitor rotary encoder for rotation
  ReadEncoder();                // Act if rotary encoder rotates
  relay_control();              // Turn Fan/Heater relays ON/OFF
  
  if (saveVolume == 1) // Update amount recetly distilled to totals  
  {
    if (water.filterVolume)
    {
      water.filterVolume = water.filterVolume + liters[menu[1]];
      water.totalVolume = water.totalVolume + liters[menu[1]];
    } else
    {
      water.filterVolume = liters[menu[1]];
      water.totalVolume = water.totalVolume + liters[menu[1]];
    }
    EEPROM_writeAnything(0, water);
    saveVolume = 0;
  }
  else if (saveVolume == 2)
  {
    water.filterVolume = 0;
    EEPROM_writeAnything(0, water);
    saveVolume = 0;
  }
  if (menu[0] == 4) // Update LCD every minute if distilling / every second if cooling down
  {
    if (relays_on && (lWaitMillis-countdown_timer) >= 60000) 
    {
      display_LCD();
      countdown_timer = lWaitMillis;
    }
    if (!relays_on && (lWaitMillis-countdown_timer) >= 1000)
    {
      display_LCD();
      countdown_timer = lWaitMillis;
    }
  }
}