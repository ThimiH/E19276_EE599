% iir_notch_filter.m
% IIR Notch Filter for removing specific frequency components
% Useful for removing power line hum (50/60 Hz)

% Import audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'}, 'Select an audio file for notch filtering');
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


% Notch filter parameters for C4 (261.63 Hz)
f0 = 261.63;    % Notch frequency (C4 note)
Q = 35;         % Quality factor (higher Q = narrower notch)
wo = f0/(fs/2); % Normalized frequency
bw = wo/Q;      % Bandwidth

% Design IIR notch filter
[b, a] = iirnotch(wo, bw);

% Apply filter
filtered_audio = filter(b, a, audio);

% Display filter information
fprintf('IIR Notch Filter Design:\n');
fprintf('Notch frequency: %.2f Hz (C4)\n', f0);
fprintf('Quality factor: %d\n', Q);
fprintf('Sampling frequency: %d Hz\n', fs);
fprintf('Normalized frequency: %.6f\n', wo);

% Visualize filter characteristics
figure('Name', 'IIR Notch Filter Analysis', 'Position', [100, 100, 1200, 800]);

% Filter frequency response
subplot(2,2,1);
[H, w] = freqz(b, a, 2048);  % Higher resolution
f_hz = w * fs / (2*pi);
plot(f_hz, 20*log10(abs(H)), 'LineWidth', 2, 'Color', [0 0.5 1]);
hold on;
% Add notch frequency line
plot([f0 f0], [-80 5], 'r--', 'LineWidth', 2);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title(sprintf('Notch Filter Frequency Response (f₀ = %.2f Hz, C4)', f0));
legend('Filter Response', sprintf('Notch: %.2f Hz (C4)', f0), 'Location', 'best');
grid on;
xlim([0 600]);
ylim([-80 5]);

% Phase response
subplot(2,2,2);
plot(f_hz, unwrap(angle(H))*180/pi, 'LineWidth', 2, 'Color', [0 0.6 0]);
hold on;
plot([f0 f0], [min(unwrap(angle(H))*180/pi) max(unwrap(angle(H))*180/pi)], 'r--', 'LineWidth', 2);
hold off;
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
title(sprintf('Notch Filter Phase Response (f₀ = %.2f Hz, C4)', f0));
legend('Phase Response', sprintf('Notch: %.2f Hz (C4)', f0), 'Location', 'best');
grid on;
xlim([0 600]);

% Pole-zero plot
subplot(2,2,3);
zplane(b, a);
title(sprintf('Pole-Zero Plot (Q = %d)', Q));
grid on;

% Spectrum comparison around notch frequency
N_fft = 4096;
f = (0:N_fft/2-1)*(fs/N_fft);
Y_orig = abs(fft(audio, N_fft));
Y_filt = abs(fft(filtered_audio, N_fft));

subplot(2,2,4);
plot(f, 20*log10(Y_orig(1:N_fft/2)), 'b', 'LineWidth', 1.5);
hold on;
plot(f, 20*log10(Y_filt(1:N_fft/2)), 'r', 'LineWidth', 1.5);
% Add notch frequency line
plot([f0 f0], [-60 60], 'k--', 'LineWidth', 1);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Spectrum Comparison (Focus on C4 Region)');
legend('Original', 'Notch Filtered', sprintf('Notch: %.2f Hz (C4)', f0), 'Location', 'best');
grid on;
xlim([10 600]);
ylim([-60 60]);

% Create additional figure for time domain analysis (2s to 2.1s)
figure('Name', 'Time Domain Analysis', 'Position', [150, 150, 1000, 400]);
start_time = 2.0;
end_time = 2.1;
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(length(audio), round(end_time * fs));
time_segment = start_sample:end_sample;

if end_sample <= length(audio)
    t = (0:length(audio)-1)/fs;
    t_segment = t(time_segment);
    
    plot(t_segment, audio(time_segment), 'b', 'LineWidth', 1.5);
    hold on;
    plot(t_segment, filtered_audio(time_segment), 'r', 'LineWidth', 1.5);
    hold off;
    xlabel('Time (s)');
    ylabel('Amplitude');
    title('Original vs Notch Filtered Audio (2.0s to 2.1s)');
    legend('Original', 'Notch Filtered', 'Location', 'best');
    grid on;
    xlim([start_time end_time]);
else
    text(0.5, 0.5, 'Audio too short for 2s-2.1s segment', ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Audio Segment Not Available');
end

% Save filtered audio
output_dir = '../samples/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'iir_notch_output.wav'], filtered_audio, fs);

fprintf('\nIIR Notch filter applied successfully!\n');
fprintf('Filtered audio saved as iir_notch_output.wav in samples folder\n');
