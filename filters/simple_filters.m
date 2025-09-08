% simple_filters.m
% Simple Low-pass and High-pass Filter Analysis

% Import audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'}, 'Select an audio file for filtering');
if isequal(file,0)
    disp('No file selected. Exiting script.');
    return;
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

N = length(audio);

% Filter coefficients
lp_coeff = [0.5 0.5]; % Low-pass
hp_coeff = [0.5 -0.5]; % High-pass

% Apply filters
lowpass = filter(lp_coeff, 1, audio);
highpass = filter(hp_coeff, 1, audio);

% Display filter information
fprintf('Simple Filter Design:\n');
fprintf('Low-pass: y[n] = 0.5x[n] + 0.5x[n-1]\n');
fprintf('High-pass: y[n] = 0.5x[n] - 0.5x[n-1]\n');
fprintf('Sampling frequency: %d Hz\n', fs);

% Visualize filter characteristics
figure('Name', 'Simple Filter Analysis', 'Position', [100, 100, 1000, 800]);

% Frequency response (magnitude only)
[Hlp, Wlp] = freqz(lp_coeff, 1, 2048, fs);
[Hhp, Whp] = freqz(hp_coeff, 1, 2048, fs);
subplot(2,2,1);
plot(Wlp, 20*log10(abs(Hlp)), 'b', 'LineWidth', 2);
hold on;
plot(Whp, 20*log10(abs(Hhp)), 'r', 'LineWidth', 2);
hold off;
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Frequency Response Comparison');
legend('Low-pass', 'High-pass');
grid on;
xlim([0 fs/2]);
ylim([-40 10]);

% Pole-zero plot (combined)
subplot(2,2,2);
zplane(lp_coeff, 1);
hold on;
zplane(hp_coeff, 1);
hold off;
title('Pole-Zero Plot');
grid on;

% Spectrum comparison (original, low-pass, high-pass)
N_fft = 4096;
f = (0:N_fft/2-1)*(fs/N_fft);
Y_orig = abs(fft(audio, N_fft));
Y_lp = abs(fft(lowpass, N_fft));
Y_hp = abs(fft(highpass, N_fft));
subplot(2,2,3);
plot(f, 20*log10(Y_orig(1:N_fft/2)), 'k', 'LineWidth', 1.2);
hold on;
plot(f, 20*log10(Y_lp(1:N_fft/2)), 'b', 'LineWidth', 1.2);
plot(f, 20*log10(Y_hp(1:N_fft/2)), 'r', 'LineWidth', 1.2);
hold off;
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Spectrum Comparison');
legend('Original', 'Low-pass', 'High-pass');
grid on;
xlim([0 fs/2]);
ylim([-60 60]);

% Time domain analysis (2s to 2.1s)
figure('Name', 'Time Domain Analysis', 'Position', [150, 150, 1000, 400]);
start_time = 2.0;
end_time = 2.1;
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(length(audio), round(end_time * fs));
time_segment = start_sample:end_sample;
if end_sample <= length(audio)
    t = (0:length(audio)-1)/fs;
    t_segment = t(time_segment);
    plot(t_segment, audio(time_segment), 'k', 'LineWidth', 1.2);
    hold on;
    plot(t_segment, lowpass(time_segment), 'b', 'LineWidth', 1.2);
    plot(t_segment, highpass(time_segment), 'r', 'LineWidth', 1.2);
    hold off;
    xlabel('Time (s)'); ylabel('Amplitude');
    title('Original vs Filtered Audio (2.0s to 2.1s)');
    legend('Original', 'Low-pass', 'High-pass');
    grid on;
    xlim([start_time end_time]);
else
    text(0.5, 0.5, 'Audio too short for 2s-2.1s segment', ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Audio Segment Not Available');
end

% Save filtered audio
output_dir = '../outputs/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'simple_lowpass_output.wav'], lowpass, fs);
audiowrite([output_dir 'simple_highpass_output.wav'], highpass, fs);

fprintf('\nSimple filters applied successfully!\n');
fprintf('Filtered audio saved as simple_lowpass_output.wav and simple_highpass_output.wav in outputs folder\n');
