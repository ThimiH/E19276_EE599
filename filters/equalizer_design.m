% equalizer_design.m
% Parametric Equalizer Design and Implementation
% Demonstrates multiple band EQ with adjustable gain, frequency, and Q

% Import audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'}, 'Select an audio file for equalizer processing');
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

% EQ Band Parameters (Low, Mid, High)
eq_bands = [
    100,  3,   6;    % Low: 100 Hz, Q=3, +6 dB boost
    1000, 2,  -4;    % Mid: 1 kHz, Q=2, -4 dB cut  
    5000, 4,   8;    % High: 5 kHz, Q=4, +8 dB boost
];

% Initialize processed audio
eq_audio = audio;
H_total = ones(2048, 1);  % Combined frequency response - higher resolution

% Display EQ parameters
fprintf('Parametric Equalizer Design:\n');
fprintf('Sampling frequency: %d Hz\n', fs);
fprintf('EQ Bands:\n');
for i = 1:size(eq_bands, 1)
    fprintf('  Band %d: %.0f Hz, Q=%.1f, %+.1f dB\n', ...
            i, eq_bands(i, 1), eq_bands(i, 2), eq_bands(i, 3));
end

figure('Name', 'Parametric Equalizer Design', 'Position', [100, 100, 1400, 900]);

% Design and apply each EQ band
for band = 1:size(eq_bands, 1)
    fc = eq_bands(band, 1);    % Center frequency
    Q = eq_bands(band, 2);     % Quality factor
    gain_dB = eq_bands(band, 3); % Gain in dB
    
    % Design peaking filter (bell curve)
    gain_linear = 10^(gain_dB/20);
    w0 = 2*pi*fc/fs;           % Digital frequency
    alpha = sin(w0)/(2*Q);     % Bandwidth parameter
    
    % Peaking EQ filter coefficients
    A = gain_linear;
    if gain_dB >= 0  % Boost
        b0 = 1 + alpha*A;
        b1 = -2*cos(w0);
        b2 = 1 - alpha*A;
        a0 = 1 + alpha/A;
        a1 = -2*cos(w0);
        a2 = 1 - alpha/A;
    else  % Cut
        b0 = 1 + alpha/A;
        b1 = -2*cos(w0);
        b2 = 1 - alpha/A;
        a0 = 1 + alpha*A;
        a1 = -2*cos(w0);
        a2 = 1 - alpha*A;
    end
    
    % Normalize coefficients
    b = [b0, b1, b2] / a0;
    a = [1, a1, a2] / a0;
    
    % Apply filter
    eq_audio = filter(b, a, eq_audio);
    
    % Calculate frequency response
    [H, w] = freqz(b, a, 2048);  % Higher resolution
    H_total = H_total .* H;
    
    % Plot individual band response
    subplot(2,3,band);
    f_hz = w * fs / (2*pi);
    color_vec = [0.2+0.3*band, 0.5, 1-0.3*band];
    color_vec = max(0, min(1, color_vec)); % Ensure RGB values are in [0,1]
    plot(f_hz, 20*log10(abs(H)), 'LineWidth', 2, 'Color', color_vec);
    xlabel('Frequency (Hz)');
    ylabel('Magnitude (dB)');
    title(sprintf('Band %d: %.0f Hz, Q=%.1f, %+.1f dB', ...
                  band, fc, Q, gain_dB));
    grid on;
    xlim([20 20000]);
    ylim([-15 15]);
    
    % Add vertical line at center frequency
    hold on;
    line([fc fc], ylim, 'Color', 'r', 'LineStyle', '--', 'LineWidth', 1.5);
    hold off;
end

% Plot combined EQ response
subplot(2,3,4);
f_hz = w * fs / (2*pi);
plot(f_hz, 20*log10(abs(H_total)), 'k', 'LineWidth', 3);
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Combined EQ Response');
grid on;
xlim([20 20000]);
set(gca, 'XScale', 'log');

% Add band markers
hold on;
for band = 1:size(eq_bands, 1)
    fc = eq_bands(band, 1);
    gain_dB = eq_bands(band, 3);
    plot(fc, gain_dB, 'ro', 'MarkerSize', 8, 'MarkerFaceColor', 'r');
end
hold off;

% Spectrum comparison (using 2s to 2.1s segment)
subplot(2,3,5);
start_time = 2.0;
end_time = 2.1;
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(length(audio), round(end_time * fs));
time_segment = start_sample:end_sample;

N_fft = 4096;
f = (0:N_fft/2-1)*(fs/N_fft);

% Use the same time segment for frequency analysis
if end_sample <= length(audio) && end_sample <= length(eq_audio)
    audio_seg = audio(time_segment);
    eq_seg = eq_audio(time_segment);
    
    % Pad or truncate to N_fft length
    if length(audio_seg) < N_fft
        audio_seg = [audio_seg; zeros(N_fft - length(audio_seg), 1)];
        eq_seg = [eq_seg; zeros(N_fft - length(eq_seg), 1)];
    else
        audio_seg = audio_seg(1:N_fft);
        eq_seg = eq_seg(1:N_fft);
    end
    
    Y_orig = abs(fft(audio_seg, N_fft));
    Y_eq = abs(fft(eq_seg, N_fft));
else
    Y_orig = abs(fft(audio, N_fft));
    Y_eq = abs(fft(eq_audio, N_fft));
end

semilogx(f(2:end), 20*log10(Y_orig(2:N_fft/2)), 'b', 'LineWidth', 1.5);
hold on;
semilogx(f(2:end), 20*log10(Y_eq(2:N_fft/2)), 'r', 'LineWidth', 1.5);
% Add band center frequencies
for band = 1:size(eq_bands, 1)
    fc = eq_bands(band, 1);
    plot([fc fc], ylim, 'k--', 'LineWidth', 1);
end
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Audio Spectrum: Before vs After EQ (2.0s to 2.1s)');
legend('Original', 'EQ Applied', 'Location', 'best');
grid on;
xlim([20 20000]);
hold off;

% Time domain comparison (2s to 2.1s)
subplot(2,3,6);
if end_sample <= length(audio)
    t = (0:length(audio)-1)/fs;
    t_segment = t(time_segment);
    
    plot(t_segment, audio(time_segment), 'b', 'LineWidth', 1.5);
    hold on;
    plot(t_segment, eq_audio(time_segment), 'r', 'LineWidth', 1.5);
    hold off;
    xlabel('Time (s)');
    ylabel('Amplitude');
    title('Waveform: Before vs After EQ (2.0s to 2.1s)');
    legend('Original', 'EQ Applied', 'Location', 'best');
    grid on;
    xlim([start_time end_time]);
else
    text(0.5, 0.5, 'Audio too short for 2s-2.1s segment', ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Audio Segment Not Available');
    xlabel('Time (s)');
    ylabel('Amplitude');
end

% Save equalized audio
output_dir = '../samples/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'equalized_audio.wav'], eq_audio/max(abs(eq_audio)), fs);

% Create a simple graphic EQ simulation
frequencies = [63, 125, 250, 500, 1000, 2000, 4000, 8000, 16000];  % Hz
gains = [2, 1, -2, 0, -3, 4, 6, 3, -1];  % dB

figure('Name', 'Graphic Equalizer Simulation', 'Position', [150, 150, 1000, 600]);
graphic_eq_audio = audio;

subplot(2,1,1);
stem(1:length(frequencies), gains, 'filled', 'LineWidth', 2, 'MarkerSize', 8);
xlabel('Band Number');
ylabel('Gain (dB)');
title('Graphic EQ Settings');
grid on;
set(gca, 'XTick', 1:length(frequencies));
set(gca, 'XTickLabel', arrayfun(@(x) sprintf('%.0f', x), frequencies, 'UniformOutput', false));
xtickangle(45);

% Apply graphic EQ (simplified using peaking filters)
H_graphic = ones(2048, 1);  % Higher resolution
for i = 1:length(frequencies)
    fc = frequencies(i);
    gain_dB = gains(i);
    Q = 1.0;  % Fixed Q for graphic EQ
    
    if abs(gain_dB) > 0.1  % Only apply if significant gain change
        gain_linear = 10^(gain_dB/20);
        w0 = 2*pi*fc/fs;
        alpha = sin(w0)/(2*Q);
        
        A = gain_linear;
        if gain_dB >= 0
            b0 = 1 + alpha*A;
            b1 = -2*cos(w0);
            b2 = 1 - alpha*A;
            a0 = 1 + alpha/A;
            a1 = -2*cos(w0);
            a2 = 1 - alpha/A;
        else
            b0 = 1 + alpha/A;
            b1 = -2*cos(w0);
            b2 = 1 - alpha/A;
            a0 = 1 + alpha*A;
            a1 = -2*cos(w0);
            a2 = 1 - alpha*A;
        end
        
        b = [b0, b1, b2] / a0;
        a = [1, a1, a2] / a0;
        
        graphic_eq_audio = filter(b, a, graphic_eq_audio);
        
        [H, w] = freqz(b, a, 2048);  % Higher resolution
        H_graphic = H_graphic .* H;
    end
end

subplot(2,1,2);
f_hz = w * fs / (2*pi);
semilogx(f_hz, 20*log10(abs(H_graphic)), 'LineWidth', 2, 'Color', [0.8 0.4 0]);
hold on;
% Add band center frequencies
for i = 1:length(frequencies)
    if abs(gains(i)) > 0.1
        plot([frequencies(i) frequencies(i)], ylim, 'k--', 'LineWidth', 1);
    end
end
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Graphic EQ Frequency Response');
grid on;
xlim([20 20000]);

% Save graphic EQ audio
audiowrite([output_dir 'graphic_eq_audio.wav'], graphic_eq_audio/max(abs(graphic_eq_audio)), fs);

fprintf('\nEqualizer design completed!\n');
fprintf('Parametric EQ bands applied: %d\n', size(eq_bands, 1));
fprintf('Graphic EQ bands applied: %d\n', length(frequencies));
fprintf('Audio files saved in samples folder:\n');
fprintf('- equalized_audio.wav (Parametric EQ)\n');
fprintf('- graphic_eq_audio.wav (Graphic EQ)\n');
