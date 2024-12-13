// 2024-12-11 by daniel reep
// v4 with background subtraction

// Get current image and title info
original = getImageID();
title = getTitle();
shortTitle = substring(title, 23, 37);
getDimensions(width, height, channels, slices, frames);

// Duplicate frame 10 for background calculation
selectImage(original);
run("Duplicate...", "duplicate range=10-10");
rename("bg_calc");
run("32-bit");

// Calculate total number of pixels in single frame
total_pixels = width * height;
n_pixels_0_1_percent = floor(total_pixels * 0.001);  // 0.1%

// Get histogram of frame 10 pixel values
getHistogram(values, counts, 256);

// Find threshold for dimmest 0.1%
cumsum = 0;
for (i = 0; i < values.length; i++) {
    cumsum += counts[i];
    if (cumsum >= n_pixels_0_1_percent) {
        bg_threshold = values[i];
        break;
    }
}

// Create mask for background pixels
setThreshold(0, bg_threshold);
run("Create Mask");
rename("bg_mask");

// Calculate mean of background pixels
run("Set Measurements...", "mean redirect=bg_calc decimal=3");
run("Measure");
bg_value = getResult("Mean", nResults-1);

// Create background-subtracted version without overwriting original
selectImage(original);
run("Duplicate...", "title=bg_subtracted duplicate");
run("Subtract...", "value=" + bg_value + " stack");
bg_subtracted = getImageID();

// Clean up background calculation windows
selectWindow("bg_calc");
close();
selectWindow("bg_mask");
close();

// Create average intensity projection of baseline frames
run("Duplicate...", "title=baseline duplicate frames=1-124");
run("Z Project...", "projection=[Average Intensity]");
baseline = getImageID();

// Create max intensity projection of analysis window
selectImage(bg_subtracted);	
run("Duplicate...", "title=analysis_window duplicate frames=125-190");
run("Z Project...", "projection=[Max Intensity]");
max_intensity = getImageID();

// Calculate percent change relative to baseline - NEW METHOD
selectImage(max_intensity);
run("32-bit");
selectImage(baseline);
run("32-bit");

// Calculate absolute change (max - baseline)
imageCalculator("Subtract create 32-bit", max_intensity, baseline);
diff_image = getImageID();

// Divide by baseline and multiply by 100 to get percent
imageCalculator("Divide create 32-bit", diff_image, baseline);
percent_change = getImageID();
run("Multiply...", "value=100");

// Create heatmap of significant changes
selectImage(percent_change);
// Create duplicate for masking
run("Duplicate...", "title=percent_mask");
// Adjust threshold to control sensitivity (e.g., 35 means 35% change) - no longer true with bkg sub
setThreshold(200, 800);
	// was 35/100 before bkg sub method
	// with bkg sub, 200/800 works for all of them
// Convert thresholded pixels to mask
run("Convert to Mask");

// Multiply mask with percent change image
selectImage(percent_change);
imageCalculator("Multiply create 32-bit", percent_change, "percent_mask");
rename("masked_changes");

// Convert to 8-bit for visualization
selectImage("masked_changes");
run("8-bit");
//setMinAndMax(200, 600);  // Will spread the visible range
	// 50-130 for G02, the largest change
//run("Enhance Contrast...", "saturated=40");  // The 40% brightness
setOption("BlackBackground", false);
run("Red");
rename("heatmap");

// Get first frame for reference and apply Cyan Hot
selectImage(original);
run("Duplicate...", "duplicate range=10-00");
rename(shortTitle + "_heatmap");

// Control background contrast - adjust these values to change contrast
// First number (50) = black level, increase to make darker parts darker
// Second number (200) = white level, decrease to make bright parts dimmer
setMinAndMax(100, 340); 
	// h03 100-340
	//
//run("Enhance Contrast...", "saturated=40");  // The 40% brightness
run("Cyan");

// Set up overlay
run("Add Image...", "image=heatmap opacity=80 zero");


// Clean up all intermediate windows
selectWindow("baseline");
close();
selectWindow("analysis_window");
close();
selectWindow("Result of MAX_analysis_window");
close();
selectWindow("Result of Result of MAX_analysis_window");
close();
selectWindow("MAX_analysis_window");
close();
selectWindow("AVG_baseline");
close();
selectWindow("percent_mask");
close();
selectWindow("bg_subtracted");
close();
selectWindow("heatmap");
close();