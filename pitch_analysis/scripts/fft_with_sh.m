% fft_with_sh.m
% Pitch estimation using FFT with harmonic suppression

% Load audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'; '*.flac'; '*.m4a'}, 'Select an audio file');
if isequal(file,0)
    error('No file selected.');
end
[audio, fs] = audioread(fullfile(path, file));

% Convert to mono if stereo
if size(audio,2) > 1
    audio = mean(audio,2);
end

% Skip first 2 second and then select a segment
skip_duration = 2.0; % seconds to skip
segment_duration = 1; % seconds
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

% Apply window to reduce spectral leakage
window = hann(length(x));
x_windowed = x .* window;

% Zero-pad for better frequency resolution
N = 2^nextpow2(4 * length(x_windowed));
X = fft(x_windowed, N);

% Get magnitude spectrum (only positive frequencies)
X_mag = abs(X(1:N/2+1));
freqs = (0:N/2) * fs / N;

% Define pitch range (typically 80-800 Hz for human voice)
f_min = 80;   % Hz
f_max = 800;  % Hz
idx_min = find(freqs >= f_min, 1);
idx_max = find(freqs <= f_max, 1, 'last');

% Extract spectrum in pitch range
pitch_spectrum = X_mag(idx_min:idx_max);
pitch_freqs = freqs(idx_min:idx_max);

% Harmonic Suppression Method
% Create a suppressed spectrum by removing harmonics
suppressed_spectrum = pitch_spectrum;

% For each potential fundamental frequency, suppress its harmonics
for i = 1:length(pitch_freqs)
    f0_candidate = pitch_freqs(i);
    
    % Find harmonic frequencies (2f0, 3f0, 4f0, etc.)
    for harmonic = 2:10  % Check up to 10th harmonic
        harmonic_freq = harmonic * f0_candidate;
        if harmonic_freq > f_max
            break;
        end
        
        % Find index closest to harmonic frequency
        [~, harmonic_idx] = min(abs(pitch_freqs - harmonic_freq));
        
        % Suppress the harmonic (set to minimum value in neighborhood)
        neighborhood = max(1, harmonic_idx-2):min(length(suppressed_spectrum), harmonic_idx+2);
        suppressed_spectrum(harmonic_idx) = min(suppressed_spectrum(neighborhood));
    end
end

% Find peak in suppressed spectrum
[~, peak_idx] = max(suppressed_spectrum);
pitch_freq_hs = pitch_freqs(peak_idx);

% Also find peak in original spectrum for comparison
[~, peak_idx_orig] = max(pitch_spectrum);
pitch_freq_orig = pitch_freqs(peak_idx_orig);

% Display results
fprintf('Original FFT method: %.2f Hz\n', pitch_freq_orig);
fprintf('Harmonic suppression method: %.2f Hz\n', pitch_freq_hs);

% Plot results
figure;
subplot(3,1,1);
plot(pitch_freqs, pitch_spectrum);
hold on;
plot(pitch_freq_orig, pitch_spectrum(peak_idx_orig), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('Original FFT Spectrum');
legend('Spectrum', 'Detected Pitch', 'Location', 'best');
grid on;

subplot(3,1,2);
plot(pitch_freqs, suppressed_spectrum);
hold on;
plot(pitch_freq_hs, suppressed_spectrum(peak_idx), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('Harmonic Suppressed Spectrum');
legend('Suppressed Spectrum', 'Detected Pitch', 'Location', 'best');
grid on;

subplot(3,1,3);
plot(pitch_freqs, pitch_spectrum, 'b-', 'LineWidth', 1);
hold on;
plot(pitch_freqs, suppressed_spectrum, 'r-', 'LineWidth', 1);
plot(pitch_freq_orig, pitch_spectrum(peak_idx_orig), 'bo', 'MarkerSize', 8, 'LineWidth', 2);
plot(pitch_freq_hs, suppressed_spectrum(peak_idx), 'ro', 'MarkerSize', 8, 'LineWidth', 2);
xlabel('Frequency (Hz)');
ylabel('Magnitude');
title('Comparison: Original vs Harmonic Suppressed');
legend('Original', 'Suppressed', 'Original Peak', 'Suppressed Peak', 'Location', 'best');
grid on;

% Calculate harmonic-to-noise ratio as a confidence measure
harmonic_strength = pitch_spectrum(peak_idx_orig) / mean(pitch_spectrum);
fprintf('Harmonic strength ratio: %.2f\n', harmonic_strength);

% Save figure with meaningful name
[~, filename_only, ~] = fileparts(file);
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, sprintf('fft_harmonic_suppression_%s.png', filename_only)));
fprintf('Figure saved as: fft_harmonic_suppression_%s.png\n', filename_only);
