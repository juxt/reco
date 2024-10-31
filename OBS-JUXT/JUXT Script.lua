---@diagnostic disable: lowercase-global, undefined-global
obs = obslua

-- Global variables for folder selection, font sizes, and user inputs
local folderPath = ""
local imageSources = {"Intro Image", "Webcam Image", "Outro Image", "JUXT Logo", "XTDB Logo"}
local cameraSources = {"Camera (Linux & Windows)", "Camera (Mac & Windows)"}
local maskFile = "Rounded.png"
local textSources = {"Main Title", "Sub Title", "Name", "Job Title"}
local textInputs = {"", "", "", ""}
local fontSizes = {0, 0, 0} -- Title, Subtitle, Name/Job Title
local juxtLogo = "JUXT Logo"
local xtdbLogo = "XTDB Logo"

-- Function to switch to the JUXT scene collection
function SwitchToJUXTCollection()
    if obs.obs_frontend_get_current_scene_collection() ~= "JUXT" then
        obs.obs_frontend_set_current_scene_collection("JUXT")
    end
end

-- Function to update all image sources with images from the selected folder
function UpdateImageSources()
    for _, image in ipairs(imageSources) do
        local imageSource = obs.obs_get_source_by_name(image)
        if imageSource then
            local settings = obs.obs_source_get_settings(imageSource)
            obs.obs_data_set_string(settings, "file", folderPath .. "/" .. image .. ".png")
            obs.obs_source_update(imageSource, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(imageSource)
        end
    end
end

-- Function to apply Image Mask/Blend filter to camera sources
function ApplyRoundingToCamera()
    local maskPath = folderPath .. "/" .. maskFile
    for _, camera in ipairs(cameraSources) do
        local cameraSource = obs.obs_get_source_by_name(camera)
        if cameraSource then
            local filter = obs.obs_source_get_filter_by_name(cameraSource, "Image Mask/Blend")
            if not filter then
                local settings = obs.obs_data_create()
                obs.obs_data_set_string(settings, "image_path", maskPath)
                obs.obs_data_set_string(settings, "type", "alpha_mask_alpha_channel")
                local newFilter = obs.obs_source_create("mask_filter", "Image Mask/Blend", settings, nil)
                obs.obs_source_filter_add(cameraSource, newFilter)
                obs.obs_data_release(settings)
                obs.obs_source_release(newFilter)
            else
                -- Update existing filter
                local settings = obs.obs_source_get_settings(filter)
                obs.obs_data_set_string(settings, "image_path", maskPath)
                obs.obs_source_update(filter, settings)
                obs.obs_data_release(settings)
                obs.obs_source_release(filter)
            end
            obs.obs_source_release(cameraSource)
        end
    end
end

-- Function to update text sources based on user input and set font size
function UpdateText()
    for i, text in ipairs(textSources) do
        local textSource = obs.obs_get_source_by_name(text)
        if textSource then
            local settings = obs.obs_source_get_settings(textSource)

            -- Set the text content
            obs.obs_data_set_string(settings, "text", textInputs[i])

            -- Set the font properties
            local fontSettings = obs.obs_data_get_obj(settings, "font")
            if fontSettings then
                if i <= 2 then
                    obs.obs_data_set_int(fontSettings, "size", fontSizes[i]) -- Apply font size for Title and Subtitle
                else
                    obs.obs_data_set_int(fontSettings, "size", fontSizes[3]) -- Apply linked size for both Name and Job Title
                end
                obs.obs_data_set_obj(settings, "font", fontSettings)
                obs.obs_data_release(fontSettings)
            end

            -- Apply the updated settings to the source so the font size can change dynamically
            obs.obs_source_update(textSource, settings)
            obs.obs_data_release(settings)
            obs.obs_source_release(textSource)
        end
    end
end

-- Function to handle the font size adjustment via dropdown list
function AdjustFontSize(textSizeIndex, newSize)
    if textSizeIndex == 3 or textSizeIndex == 4 then
        -- Link font size for Name and Job Title
        fontSizes[3] = newSize
    else
        -- Adjust font size for individual text sources
        fontSizes[textSizeIndex] = newSize
    end
    UpdateText() -- Re-apply the updated text with the new font sizes
end

-- Function to show or hide the logos depending on the selected radio button
function UpdateLogoVisibilities(logoOption)
    -- Loop through each scene
    for _, sceneSource in ipairs(obs.obs_frontend_get_scenes()) do
        local scene = obs.obs_scene_from_source(sceneSource)

        -- Get the scene object for XTDB & JUXT logo
        local XTDB = obs.obs_scene_find_source(scene, xtdbLogo)
        local JUXT = obs.obs_scene_find_source(scene, juxtLogo)

        -- Check which logo option is selected and set visibility
        if logoOption == "JUXT" then
            if JUXT then
                obs.obs_sceneitem_set_visible(JUXT, true)  -- Show JUXT logo
            end
            if XTDB then
                obs.obs_sceneitem_set_visible(XTDB, false)  -- Hide XTDB logo
            end
        elseif logoOption == "XTDB" then
            if JUXT then
                obs.obs_sceneitem_set_visible(JUXT, false)  -- Hide JUXT logo
            end
            if XTDB then
                obs.obs_sceneitem_set_visible(XTDB, true)  -- Show XTDB logo
            end
        end
        obs.obs_source_release(sceneSource)
    end
end

-- Called when the user updates settings in the script
function script_update(settings)
    -- Switch to JUXT scene collection if not already active
    SwitchToJUXTCollection()

    -- Get the folder path from user input
    folderPath = obs.obs_data_get_string(settings, "folderPath")
    
    -- Update text input from user
    textInputs[1] = obs.obs_data_get_string(settings, "titleInput")
    textInputs[2] = obs.obs_data_get_string(settings, "subtitleInput")
    textInputs[3] = obs.obs_data_get_string(settings, "nameInput")
    textInputs[4] = obs.obs_data_get_string(settings, "jobTitleInput")
    
    -- Get the selected font sizes from the combo boxes and update accordingly
    AdjustFontSize(1, obs.obs_data_get_int(settings, "titleSizeDropdown"))
    AdjustFontSize(2, obs.obs_data_get_int(settings, "subtitleDropdown"))
    AdjustFontSize(3, obs.obs_data_get_int(settings, "nameJobTitleDropdown"))

    -- Get the selected logo option (JUXT or XTDB)
    local logoOption = obs.obs_data_get_string(settings, "logoChoice")

    -- Update sources with new data
    UpdateImageSources()
    ApplyRoundingToCamera()
    UpdateText()

    -- Now use the function to update logo visibility based on the selected option
    UpdateLogoVisibilities(logoOption)
end

-- UI elements in the OBS script window
function script_properties()
    local props = obs.obs_properties_create()

    -- Folder selection for images
    obs.obs_properties_add_path(props, "folderPath", "Select Image Folder", obs.OBS_PATH_DIRECTORY, "", folderPath)

    -- Main Title
    obs.obs_properties_add_text(props, "titleInput", "Title", obs.OBS_TEXT_MULTILINE)

    -- Add size dropdown list for Title (150 to 350, increments of 25)
    local titleSizeDropdown = obs.obs_properties_add_list(props, "titleSizeDropdown", "Title Font Size", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    for i = 150, 350, 25 do
        obs.obs_property_list_add_int(titleSizeDropdown, tostring(i), i)
    end

    -- Subtitle
    obs.obs_properties_add_text(props, "subtitleInput", "Subtitle", obs.OBS_TEXT_MULTILINE)

    -- Add size dropdown list for Subtitle (150 to 350, increments of 25)
    local subtitleDropdown = obs.obs_properties_add_list(props, "subtitleDropdown", "Subtitle Font Size", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    for i = 150, 350, 25 do
        obs.obs_property_list_add_int(subtitleDropdown, tostring(i), i)
    end

    -- Name
    obs.obs_properties_add_text(props, "nameInput", "Your Name", obs.OBS_TEXT_DEFAULT)

    -- Job Title
    obs.obs_properties_add_text(props, "jobTitleInput", "Job Title", obs.OBS_TEXT_DEFAULT)

    -- Add size dropdown list for Name and Job Title (linked) (150 to 350, increments of 25)
    local nameJobTitleDropdown = obs.obs_properties_add_list(props, "nameJobTitleDropdown", "Name/Job Title Font Size", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_INT)
    for i = 150, 350, 25 do
        obs.obs_property_list_add_int(nameJobTitleDropdown, tostring(i), i)
    end

    -- Radio buttons for logo selection (JUXT or XTDB)
    local logoChoice = obs.obs_properties_add_list(props, "logoChoice", "Are you producing content for JUXT or XTDB?", obs.OBS_COMBO_TYPE_LIST, obs.OBS_COMBO_FORMAT_STRING)
    obs.obs_property_list_add_string(logoChoice, "JUXT", "JUXT")
    obs.obs_property_list_add_string(logoChoice, "XTDB", "XTDB")

    return props
end

-- Description of the script
function script_description() 
    return [[
        This script automates the following actions:
        1. Switches to the "JUXT" scene collection if not already active.
        2. Allows the user to select a folder which will load in all necessary images
        4. Applies a Image Mask/Blend (Rounded) filter to camera sources.
        5. Allows text input for the main title, subtitle, name, and job title.
        6. Allows the user to adjust the font size for each text.
        6. Shows or hides the JUXT or XTDB logos based on the selected option.
    ]]
end
