
# A Fully Customizable FPGA Function Generator

In human-computer interaction, increasingly complex grids of actuators are used for tactile feedback. 
Effects on the skin such as *"Cutaneous Rabbit"* or *"Phantom Sensation"* require increased circuitry with a large number of actuators. 
Particularly with the advent of increasingly realistic virtual worlds, new methods are being explored to increase immersion by tactile effects. 
In addition to vibration, electrical muscle stimulation (EMS) is becoming increasingly important for tactile feedback.

To ensure mobile use and in-depth exploration of tactile effects, we have developed *MultiWave* - a fully customizable and scalable function generator. This open-source project was developed to provide HCI researchers with a mobile function generator to study tactile effects on complex actuator grids.  With MultiWave, amplitude, phase, frequency, and waveform can be freely adjusted to discover new effects on human skin. The various parameters can be set via UART with simple commands. Depending on your FPGA (default: DE10-Nano), the signal quantization or PWM steps (default: 10Bit), the amplitude gain quantization (default: 8Bit), the number of actuators (default: 80 ports) and the number of different periodic signals (default: 128 functions including sine, triangle, square, sawtooth) can be freely defined. In addition, the phase of each output signal can be adjusted in relation to any other output.

<img src = “Images/Board_view.png”>

## Application example

With MultiWave you can experience virtual worlds immersively everywhere. 
We created a virtual world and a mobile bodysuit to explore the possibilities of MultiWave. 
On *"Sensation Island"* we showed how it feels to take a waterfall shower and fall from great heights. 
Would you like to experience this too? Click the image below to watch our video and see how virtual worlds can merge with reality in the future.

[<img src="Images/MultiWaveVR.jpg">](https://www.youtube.com/watch?v=o4MZdf-5J6U "Video:  MultiWave: A Mobile Function Generator for Haptic Feedback in VR")

## How it works

The picture below shows a simplified overview of the structure. 
In the folder *Block Diagram* you will find a detailed view of the block diagram. 
You will also find a detailed description of the protocol in the folder *UART Protocol*.  
Internally, PWM signals are controlled by a logic unit based on your defined signals stored in RAMs. 
Via UART you can freely control the data content of the RAMs and all other signal parameters customizable via the update logic.  
To avoid overloading the FPGA outputs you have to control your actuators via MOSFETs. 
It is recommended to smooth the outputs via capacitors to attentuate high frequency noise for voice coil actuators. 
You can find further information in [*our paper*](MultiWave.pdf).

<img src = “Images/BSB_wave.png”>


## Award & Research recognition

MultiWave was part of the _InnovateFPGA Design Contest_ in 2019 and successfully awarded with the [*Regional Final Bronze Award*](https://www.hci.uni-hannover.de/de/institut/news-und-events/news/aktuelles-detailansicht/news/regional-final-bronze-award-at-innovatefpga-2019). 
We are very honored to receive this award. Furthermore, we are pleased that Dr. Kaul was able to successfully use MultiWave for his research on tactile feedback around the head. 
As part of his dissertation and paper [*VRTactileDraw*](https://link.springer.com/chapter/10.1007/978-3-030-85607-6_15) we feel honored to have contributed to HCI research on tactile perception.


## License
[MIT](https://choosealicense.com/licenses/mit/)

##
![HCI Group](/Images/Institute.png)

This repository is provided by the Human-Computer Interaction Group at the University Hannover, Germany. For additional details, see [*our paper*](MultiWave.pdf) included in this repository. 
The code is licsened under MIT license. For inquiries, please contact maximilian.schrapel@hci.uni-hannover.de

