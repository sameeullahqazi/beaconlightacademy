// set the common device dimensions here for mobile / tablet / desktop

//Breakpoints taken from Bootstrap 4

/* Small devices (landscape phones, 576px and up) */
const mobileWidthLowerLimit = 576;

/* Medium devices (tablets, 768px and up) */
const tabletWidthLowerLimit = 768;

/* Large devices (desktops, 992px and up) */
const desktopWidthLowerLimit = 992;

/* Extra large devices (large desktops, 1200px and up) */
const extraLargeWidthLowerLimit = 1200;

const fontSizeMultiplier = 300;

double calculateFontSize(maxFontSize, currentWidth) {
  double newSize = maxFontSize * (currentWidth / fontSizeMultiplier);
  if (maxFontSize <= newSize) {
    return maxFontSize.toDouble();
  } else {
    return newSize;
  }
}
