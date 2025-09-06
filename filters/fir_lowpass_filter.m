% fir_lowpass_filter.m
% FIR Low-pass Filter Design and Application
% Demonstrates finite impulse response filtering

% Import audio file
[file, path] = uigetfile({'*.wav'}, 'Select an audio file for LPC pitch estimation');
if isequal(file,0)
    disp('No file selected. Exiting script.');
    return; % Exit if no file is selected
end
audio_filepath = fullfile(path, file);

try
    [audio, fs] = audioread(audio_filepath);
catch ME
    fprintf('Error loading audio file: %s\n', ME.message);
    return;
end

% If stereo, convert to mono
if size(audio, 2) > 1
    audio = mean(audio, 2);
end

% Filter parameters
fc = 2000;      % Cutoff frequency (2 kHz)
N = 50;         % Filter order
Wn = fc/(fs/2); % Normalized cutoff frequency

% Design FIR low-pass filter using window method
b = fir1(N, Wn, 'low');
a = 1;

% Apply filter
filtered_audio = filter(b, a, audio);

% Display filter information
fprintf('FIR Low-pass Filter Design:\n');
fprintf('Cutoff frequency: %d Hz\n', fc);
fprintf('Filter order: %d\n', N);
fprintf('Sampling frequency: %d Hz\n', fs);
fprintf('Normalized cutoff: %.4f\n', Wn);

% Visualize filter frequency response
figure('Name', 'FIR Low-pass Filter Analysis', 'Position', [100, 100, 1200, 800]);
subplot(2,2,1);
[H, w] = freqz(b, a, 2048, fs);  % Increased resolution
plot(w, 20*log10(abs(H)), 'LineWidth', 2, 'Color', [0 0.5 1]);
hold on;
% Add cutoff frequency line
plot([fc fc], [-80 10], 'r--', 'LineWidth', 2);
% Add -3dB line
plot([0 fs/2], [-3 -3], 'k:', 'LineWidth', 1);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title(sprintf('FIR Low-pass Filter Frequency Response (fc = %d Hz)', fc));
legend('Filter Response', sprintf('Cutoff: %d Hz', fc), '-3dB Line', 'Location', 'best');
grid on;
xlim([0 fs/2]);
ylim([-80 10]);

% Plot impulse response
subplot(2,2,2);
[h, n] = impz(b, a, 51);
stem(n, h, 'LineWidth', 1.5);
xlabel('Sample Number');
ylabel('Amplitude');
title('FIR Filter Impulse Response');
grid on;

% Compare original and filtered waveforms (2s to 2.1s segment)
t = (0:length(audio)-1)/fs;
start_time = 2.0;  % Start at 2 seconds
end_time = 2.1;    % End at 2.1 seconds
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(length(audio), round(end_time * fs));
time_segment = start_sample:end_sample;

subplot(2,2,3);
if end_sample <= length(audio) && end_sample <= length(filtered_audio)
    t_segment = t(time_segment);
    plot(t_segment, audio(time_segment), 'b', 'LineWidth', 1.5);
    hold on;
    plot(t_segment, filtered_audio(time_segment), 'r', 'LineWidth', 1.5);
    hold off;
    xlabel('Time (s)');
    ylabel('Amplitude');
    title('Original vs Filtered Audio (2.0s to 2.1s)');
    legend('Original', 'Filtered', 'Location', 'best');
    grid on;
    xlim([start_time end_time]);
else
    text(0.5, 0.5, 'Audio too short for 2s-2.1s segment', ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Audio Segment Not Available');
    xlabel('Time (s)');
    ylabel('Amplitude');
end

% Plot frequency spectra comparison (using 2s to 2.1s segment)
N_fft = 2048;
f = (0:N_fft/2-1)*(fs/N_fft);

% Use the same time segment for frequency analysis
if end_sample <= length(audio) && end_sample <= length(filtered_audio)
    audio_segment = audio(time_segment);
    filtered_segment = filtered_audio(time_segment);
    
    % Pad or truncate to N_fft length
    if length(audio_segment) < N_fft
        audio_segment = [audio_segment; zeros(N_fft - length(audio_segment), 1)];
        filtered_segment = [filtered_segment; zeros(N_fft - length(filtered_segment), 1)];
    else
        audio_segment = audio_segment(1:N_fft);
        filtered_segment = filtered_segment(1:N_fft);
    end
    
    Y_orig = abs(fft(audio_segment, N_fft));
    Y_filt = abs(fft(filtered_segment, N_fft));
else
    % Fallback to full audio if segment not available
    Y_orig = abs(fft(audio, N_fft));
    Y_filt = abs(fft(filtered_audio, N_fft));
end

subplot(2,2,4);
plot(f, 20*log10(Y_orig(1:N_fft/2)), 'b', 'LineWidth', 1.5);
hold on;
plot(f, 20*log10(Y_filt(1:N_fft/2)), 'r', 'LineWidth', 1.5);
% Add cutoff frequency line
plot([fc fc], [-60 60], 'k--', 'LineWidth', 1);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Frequency Spectrum Comparison (2.0s to 2.1s segment)');
legend('Original', 'Filtered', sprintf('Cutoff: %d Hz', fc), 'Location', 'best');
grid on;
xlim([0 5000]);
ylim([-60 60]);

% Create additional figure for phase analysis
figure('Name', 'FIR Filter Phase Analysis', 'Position', [150, 150, 1000, 600]);
subplot(2,1,1);
[H, w] = freqz(b, a, 2048, fs);  % Higher resolution for smoother curves
plot(w, unwrap(angle(H))*180/pi, 'LineWidth', 2, 'Color', [0 0.6 0]);
hold on;
plot([fc fc], [min(unwrap(angle(H))*180/pi) max(unwrap(angle(H))*180/pi)], 'r--', 'LineWidth', 2);
hold off;
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
title(sprintf('FIR Low-pass Filter Phase Response (fc = %d Hz)', fc));
legend('Phase Response', sprintf('Cutoff: %d Hz', fc), 'Location', 'best');
grid on;
xlim([0 fs/2]);

subplot(2,1,2);
[gd, w_gd] = grpdelay(b, a, 2048, fs);  % Higher resolution
plot(w_gd, gd, 'LineWidth', 2, 'Color', [0.8 0.4 0]);
hold on;
plot([fc fc], [min(gd) max(gd)], 'r--', 'LineWidth', 2);
hold off;
xlabel('Frequency (Hz)');
ylabel('Group Delay (samples)');
title(sprintf('FIR Low-pass Filter Group Delay (fc = %d Hz)', fc));
legend('Group Delay', sprintf('Cutoff: %d Hz', fc), 'Location', 'best');
grid on;
xlim([0 fs/2]);

% Save filtered audio
output_dir = '../samples/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'fir_lowpass_output.wav'], filtered_audio, fs);

fprintf('\nFIR Low-pass filter applied successfully!\n');
fprintf('Filtered audio saved as fir_lowpass_output.wav in samples folder\n');
fprintf('Two analysis figures have been generated:\n');
fprintf('1. Filter characteristics and audio comparison\n');
fprintf('2. Phase response and group delay analysis\n');
