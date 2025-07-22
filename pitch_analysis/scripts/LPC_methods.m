% Improved LPC_methods.m
% Estimate pitch using LPC (Linear Predictive Coding) with enhancements

% --- 1. Load Audio File ---
% Allow user to select an audio file, or use a default if it exists
[file, path] = uigetfile({'*.wav'}, 'Select an audio file for LPC pitch estimation');
if isequal(file,0)
    disp('No file selected. Exiting script.');
    return; % Exit if no file is selected
end
audio_filepath = fullfile(path, file);

try
    [x, fs] = audioread(audio_filepath);
catch ME
    fprintf('Error loading audio file: %s\n', ME.message);
    return;
end

% Convert to mono if stereo
if size(x,2) > 1
    x = mean(x,2);
    fprintf('Converted stereo audio to mono.\n');
end

% Normalize audio to prevent clipping and ensure consistent amplitude
x = x / max(abs(x));

% --- 2. Pre-emphasis Filter ---
% Pre-emphasis filter (optional, but generally improves LPC performance for speech)
pre_emphasis_coeff = 0.97;
x_preemphasized = filter([1 -pre_emphasis_coeff], 1, x);
fprintf('Applied pre-emphasis filter with coefficient %.2f.\n', pre_emphasis_coeff);

% --- 3. Frame Parameters ---
frameLen = round(0.03 * fs); % 30 ms frames (common for speech)
frameStep = round(0.01 * fs); % 10 ms step (overlap for smooth contour)
lpcOrder = 12; % Typical LPC order for speech (usually fs/1000 + 2 to 4)

% Define pitch search range (Hz)
f_min_pitch = 50;  % Lower bound for human voice pitch
f_max_pitch = 500; % Upper bound for human voice pitch

% Convert pitch range to lag samples
minLagSamples = round(fs / f_max_pitch); % Corresponds to f_max_pitch
maxLagSamples = round(fs / f_min_pitch); % Corresponds to f_min_pitch

% --- 4. Pitch Estimation for Each Frame ---
numFrames = floor((length(x_preemphasized) - frameLen) / frameStep) + 1;
pitchHz = NaN(numFrames,1); % Initialize with NaN for unvoiced segments
frame_energy = zeros(numFrames,1); % For voiced/unvoiced detection

fprintf('Processing %d frames...\n', numFrames);

for i = 1:numFrames
    % Define current frame indices
    idx = (1:frameLen) + (i-1)*frameStep;
    
    % Apply Hamming window to the frame
    frame = x_preemphasized(idx) .* hamming(frameLen);

    % Calculate frame energy (for simple V/UV detection)
    frame_energy(i) = sum(frame.^2);

    % --- Voiced/Unvoiced Detection (Simple Energy Threshold) ---
    % This is a very basic V/UV. More sophisticated methods exist.
    % Adjust threshold based on your audio data characteristics.
    energy_threshold = 0.001 * max(frame_energy); % Example threshold, adjust as needed

    if frame_energy(i) < energy_threshold
        % Consider this frame unvoiced, pitch will remain NaN
        continue; 
    end

    % --- LPC Analysis ---
    % Compute LPC coefficients
    a = lpc(frame, lpcOrder);

    % Compute residual (excitation signal)
    % The residual is the error signal after predicting the current sample
    % from past samples using the LPC coefficients. For voiced speech,
    % it should reveal the periodic excitation.
    residual = filter(a, 1, frame);

    % --- Autocorrelation of Residual ---
    % Compute autocorrelation of the residual
    % We are interested in the periodicity of the residual.
    % xcorr returns correlation for positive and negative lags. We only need positive.
    % Limiting lag to maxLagSamples improves efficiency and focuses on pitch range.
    [acor, lag] = xcorr(residual, maxLagSamples, 'coeff'); % 'coeff' normalizes
    acor = acor(lag >= 0); % Keep only non-negative lags
    lag = lag(lag >= 0);

    % --- Find Pitch Lag from Autocorrelation Peak ---
    % Ignore very short lags (below minLagSamples, corresponding to high frequencies)
    % Search for the maximum peak within the valid pitch lag range.
    
    % Find indices corresponding to the valid lag range
    valid_lag_indices = find(lag >= minLagSamples & lag <= maxLagSamples);

    if isempty(valid_lag_indices)
        % No valid lags in the specified range, pitch remains NaN
        continue;
    end

    % Extract autocorrelation values for the valid lag range
    acor_valid_range = acor(valid_lag_indices);
    
    % Find the peak (maximum value) in this valid range
    [peak_val, peak_idx_in_range] = max(acor_valid_range);
    
    % Get the actual lag value corresponding to the peak
    pitchLag = lag(valid_lag_indices(peak_idx_in_range));

    % Add a simple confidence check: peak must be above a certain value
    % This helps filter out weak or noisy peaks.
    min_peak_correlation = 0.3; % Adjust this threshold
    if peak_val > min_peak_correlation
        % Convert lag to frequency
        pitchHz(i) = fs / pitchLag;
    else
        % Peak too low, consider it unvoiced or unreliable pitch
        pitchHz(i) = NaN;
    end
end

% --- 5. Post-processing: Smooth Pitch Contour ---
% Apply a median filter to smooth the pitch contour and remove outliers
% A 3-point median filter is common for pitch.
smoothed_pitchHz = medfilt1(pitchHz, 3, 'omitnan', 'truncate'); % 'omitnan' to handle NaNs

% --- 6. Plot Pitch Contour ---
time = ((1:numFrames)*frameStep + frameLen/2)/fs; % Center time for each frame

figure('Position', [100, 100, 1000, 700]); % Adjust figure size

% Subplot 1: Original Audio Waveform
subplot(2,1,1);
plot((0:length(x)-1)/fs, x, 'b', 'LineWidth', 0.8);
hold on;
% Mark the analyzed segment (e.g., first segment)
plot(time(1), x(round(time(1)*fs)), 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Audio Waveform: %s', file));
grid on;
xlim([0, length(x)/fs]); % Ensure full waveform is shown

% Subplot 2: Estimated Pitch Contour
subplot(2,1,2);
plot(time, smoothed_pitchHz, 'r-', 'LineWidth', 1.5);
hold on;
% Plot original (unsmoothed) pitch for comparison (optional)
plot(time, pitchHz, 'k:', 'LineWidth', 0.8, 'DisplayName', 'Unsmoothed Pitch');
xlabel('Time (s)');
ylabel('Estimated Pitch (Hz)');
title('Pitch Estimation using LPC (Smoothed)');
grid on;
ylim([f_min_pitch-10, f_max_pitch+10]); % Set y-limits based on expected pitch range
legend('Smoothed Pitch', 'Unsmoothed Pitch', 'Location', 'best');

% Add a horizontal line for the average pitch (excluding NaNs)
avg_pitch = nanmean(smoothed_pitchHz);
if ~isnan(avg_pitch)
    yline(avg_pitch, 'g--', sprintf('Average: %.1f Hz', avg_pitch), 'LineWidth', 1);
end

fprintf('\nPitch estimation complete. Check the generated plot.\n');
fprintf('Average detected pitch (excluding unvoiced frames): %.2f Hz\n', avg_pitch);

% Save figure with meaningful name
[~, filename_only, ~] = fileparts(file);
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, sprintf('LPC_pitch_analysis_%s.png', filename_only)));
fprintf('Figure saved as: LPC_pitch_analysis_%s.png\n', filename_only);
