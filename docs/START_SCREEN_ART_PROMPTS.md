# Start-screen art prompts

Generated through APIXGo openai group, model `gpt-image-2.5-flare`, with the imagegen skill CLI.

## prompt

Use case: illustration-story / mobile game UI illustration.
Asset type: a single polished START ADVENTURE button illustration for the existing Forest Star mobile game title screen.
Input image 1 is the overall illustration style reference. Input image 2 is the existing paper-and-gold interface frame style reference.
Create ONE beautifully crafted, chunky horizontal woodland fantasy game button, centered on a plain flat pure white background for clean extraction. The button is a warm polished golden honey-coloured carved wooden and creamy enamel plaque with a deep forest-green inset centre. A raised rounded rectangular silhouette with a gently curved top and bottom edge, rich bevelled golden edges, subtle carved grain, tiny brass star studs, a delicate small glowing blue-green crystal at each side and a few tasteful tiny cream flowers near the far left and right tips. Make the surface feel satisfyingly tactile, three-dimensional, premium, cute and hand-painted, matching the storybook illustration and gold-edged UI frames in the references. Soft warm upper-left light and restrained material highlights.
Composition: only one isolated button, approximately 3.5 to 1 width-to-height, occupying the central 85% of the canvas width and about 32% of its height. Leave clear WHITE space all around the outer silhouette, with no objects touching the canvas edges. The far left and right ornaments stay within the button's overall outline.
The CENTRAL 65% of the button surface must be a QUIET empty smooth deep forest-green enamel area, with absolutely NO lettering or symbols, because the Flutter app overlays its exact localized text "開始冒險" there. Do NOT draw any text, letters, Chinese characters, numbers, logos, arrows, play icons, watermarks, hands, characters or a surrounding scene. No extra buttons, no big leaves at the top, no vines crossing the blank centre. Do not draw a cast shadow outside the silhouette; shade and bevel the actual button only.

## background-prompt

Use case: precise-object-edit.
Asset type: static full-screen background for an animated mobile game title screen.
Image 1 is the original Forest Star start-screen illustration and edit target. Preserve its exact cozy hand-painted forest storybook art, warm natural sunlight, rounded trees, mountains, sky, meadow, flower colours, perspective and atmosphere.
Remove ALL animals and characters from the foreground and middle ground. Remove any baked-in title, lettering, button, logo, labels or interface if present. Reconstruct those regions as a continuous lovely empty grass-and-flower clearing with a winding dirt path, matching the surrounding brushwork. The bottom two thirds must offer a quiet, open clearing so separately animated rabbit, otter and fox sprites can appear there, with the actual UI overlaid later by Flutter. Keep distant scenery, the original framing foliage and the blue sky. No buildings or new props. Do not paint any replacement animals, characters, buttons, lettering or logos. Full-bleed portrait illustration without any outer border. This is only a clean background layer; the living characters will be drawn by the game framework.


Post-processing: remove the connected white matte from the generated button, preserve the coloured silhouette and alpha edges, crop transparent margins, retain text as a native Flutter overlay. Background converted to WebP.
