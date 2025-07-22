% welchs_PSD.m
% Pitch estimation using Welch's Power Spectral Density method

% Load audio file
[file, path] = uigetfile({'*.wav'}, 'Select an audio file');
if isequal(file,0)
    error('No file selected.');
end
[audio, fs] = audioread(fullfile(path, file));

% Convert to mono if stereo
if size(audio,2) > 1
    audio = mean(audio,2);
end

% Skip first 1 second and then select a longer segment for better PSD estimation
skip_duration = 1.0; % seconds to skip
segment_duration = 0.1; % seconds (longer segment for better PSD)
skip_samples = round(skip_duration * fs);
segment_samples = round(segment_duration * fs);
start_idx = skip_samples + 1;
end_idx = start_idx + segment_samples - 1;

% Ensure we don't exceed audio length
if end_idx > length(audio)
    error('Audio file is too short. Need at least %.2f seconds.', skip_duration + segment_duration);
end

x = audio(start_idx:end_idx);

% Remove DC offset
x = x - mean(x);

% Welch's method parameters
window_length = round(segment_samples / 4); % 25% of segment length
overlap = round(window_length * 0.5);       % 50% overlap
nfft = 2^nextpow2(window_length * 2);       % Zero-padding for better resolution

% Compute PSD using Welch's method with Hann window
fprintf('Computing PSD using Hann window...\n');

% Use Hann window (most common and effective)
[psd, f] = pwelch(x, hann(window_length), overlap, nfft, fs);

% Define pitch range (typical for human voice/instruments)
f_min = 80;   % Hz
f_max = 800;  % Hz

% Find pitch using Hann window
[pitch_freq, pitch_power, confidence] = find_pitch_from_psd(psd, f, f_min, f_max);

% Display results
fprintf('\n=== Pitch Estimation Results ===\n');
fprintf('Detected pitch: %.2f Hz (Confidence: %.2f)\n', pitch_freq, confidence);

% Set the final pitch result
if ~isnan(pitch_freq)
    final_pitch = pitch_freq;
    fprintf('\nFinal pitch estimate: %.2f Hz\n', final_pitch);
else
    fprintf('\nNo valid pitch detected!\n');
    final_pitch = NaN;
end

% Create comprehensive plots
figure('Position', [100, 100, 1200, 800]);

% Plot 1: Time domain signal
subplot(2, 2, 1);
t = (0:length(x)-1) / fs;
plot(t, x, 'b-', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Amplitude');
title('Audio Signal Segment');
grid on;

% Plot 2: PSD (full frequency range)
subplot(2, 2, 2);
semilogy(f, psd, 'b-', 'LineWidth', 1.5);
xlabel('Frequency (Hz)');
ylabel('Power Spectral Density (dB/Hz)');
title('Power Spectral Density - Full Range');
grid on;
xlim([0, fs/2]);

% Plot 3: PSD in pitch range with detected pitch
subplot(2, 2, 3);
idx_plot = f >= f_min & f <= f_max;
plot(f(idx_plot), psd(idx_plot), 'b-', 'LineWidth', 2);
hold on;

% Mark detected pitch
if ~isnan(pitch_freq)
    plot(pitch_freq, pitch_power, 'ro', 'MarkerSize', 10, 'MarkerFaceColor', 'r', 'LineWidth', 2);
    text(pitch_freq, pitch_power*1.1, sprintf('%.1f Hz', pitch_freq), ...
         'HorizontalAlignment', 'center', 'FontWeight', 'bold', 'FontSize', 12);
end

xlabel('Frequency (Hz)');
ylabel('Power Spectral Density');
title('PSD in Pitch Range (80-800 Hz)');
grid on;

% Plot 4: Harmonic analysis
subplot(2, 2, 4);
if ~isnan(final_pitch)
    % Show potential harmonics
    harmonics = (1:6) * final_pitch;
    harmonic_powers = zeros(size(harmonics));
    
    for i = 1:length(harmonics)
        if harmonics(i) <= max(f)
            [~, h_idx] = min(abs(f - harmonics(i)));
            harmonic_powers(i) = psd(h_idx);
        end
    end
    
    semilogy(harmonics, harmonic_powers, 'ro-', 'MarkerSize', 8, 'MarkerFaceColor', 'r', 'LineWidth', 2);
    hold on;
    
    % Overlay full PSD for reference (using lighter color instead of alpha)
    semilogy(f, psd, 'Color', [0.7, 0.7, 1], 'LineWidth', 1);
    
    % Add harmonic labels
    for i = 1:length(harmonics)
        if harmonics(i) <= max(f) && harmonic_powers(i) > 0
            text(harmonics(i), harmonic_powers(i)*1.5, sprintf('%d×F0', i), ...
                 'HorizontalAlignment', 'center', 'FontSize', 10);
        end
    end
    
    xlabel('Frequency (Hz)');
    ylabel('Power Spectral Density');
    title(sprintf('Harmonic Analysis (F0 = %.1f Hz)', final_pitch));
    legend('Detected Harmonics', 'PSD', 'Location', 'best');
    grid on;
    xlim([0, 6*final_pitch]);
else
    text(0.5, 0.5, 'No pitch detected', 'HorizontalAlignment', 'center', 'Units', 'normalized', 'FontSize', 14);
    title('Harmonic Analysis - No Pitch Detected');
end

% Additional analysis: Pitch confidence metrics
fprintf('\n=== Analysis Details ===\n');
fprintf('Segment duration: %.3f seconds\n', segment_duration);
fprintf('Window length: %d samples (%.3f seconds)\n', window_length, window_length/fs);
fprintf('Overlap: %d samples (%.1f%%)\n', overlap, 100*overlap/window_length);
fprintf('FFT length: %d points\n', nfft);
fprintf('Frequency resolution: %.2f Hz\n', fs/nfft);

if ~isnan(final_pitch)
    fprintf('\n=== Pitch Validation ===\n');
    % Check if detected pitch has strong harmonics
    fundamental_power = interp1(f, psd, final_pitch);
    second_harmonic_power = interp1(f, psd, 2*final_pitch);
    
    if ~isnan(second_harmonic_power)
        harmonic_ratio = second_harmonic_power / fundamental_power;
        fprintf('Fundamental/2nd harmonic ratio: %.2f\n', 1/harmonic_ratio);
        
        if harmonic_ratio > 0.1
            fprintf('Strong harmonic content detected - good pitch confidence\n');
        else
            fprintf('Weak harmonic content - lower pitch confidence\n');
        end
    end
end

% Save figure with meaningful name
[~, filename_only, ~] = fileparts(file);
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, sprintf('welchs_PSD_analysis_%s.png', filename_only)));
fprintf('Figure saved as: welchs_PSD_analysis_%s.png\n', filename_only);

% Function to find pitch from PSD
function [pitch_freq, pitch_power, confidence] = find_pitch_from_psd(psd, f, f_min, f_max)
    % Find indices for pitch range
    idx_min = find(f >= f_min, 1);
    idx_max = find(f <= f_max, 1, 'last');
    
    if isempty(idx_min) || isempty(idx_max)
        pitch_freq = NaN;
        pitch_power = NaN;
        confidence = 0;
        return;
    end
    
    % Extract PSD in pitch range
    psd_pitch = psd(idx_min:idx_max);
    f_pitch = f(idx_min:idx_max);
    
    % Smooth the PSD to reduce noise
    if length(psd_pitch) > 10
        psd_smooth = smooth(psd_pitch, 5);
    else
        psd_smooth = psd_pitch;
    end
    
    % Find peak in PSD
    [peak_power, peak_idx] = max(psd_smooth);
    pitch_freq = f_pitch(peak_idx);
    pitch_power = peak_power;
    
    % Calculate confidence as ratio of peak to mean
    mean_power = mean(psd_smooth);
    confidence = peak_power / mean_power;
end
