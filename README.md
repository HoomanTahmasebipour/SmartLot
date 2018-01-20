# SmartLot
Used the DE1-Soc Board and the HC-SR04 sensor to replicate crash prevention technology in modern cars with a list of available spots inside a parking lot.

The sensor's range is from 2 cm to 5 m, in order to make the range more useful, the user will be alreted of imminent crash when the distance between 
the object and the sensor goes below 10 cm. When this happens a beeping sound is triggered from the speaker and the display shows that a car has filled
up the remainng spot. As the object get closer to the sensor, the frequency of the beeps increase. If the object gets too close to the sensor (less than
4 cm) the frequency of the beeps reaches its max and the screen begins to flash "Crash".