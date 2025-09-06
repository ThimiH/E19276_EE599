% elliptic_bandpass_filter.m
% Elliptic (Cauer) Bandpass Filter Design
% Demonstrates steep roll-off characteristics with minimal order

% Import audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'}, 'Select an audio file for elliptic bandpass filtering');
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

% Filter specifications for voice isolation
Wp = [300 3400]/(fs/2);    % Passband edges (normalized)
Ws = [200 4000]/(fs/2);    % Stopband edges (normalized)
Rp = 1;                    % Passband ripple (dB)
Rs = 40;                   % Stopband attenuation (dB)

% Design elliptic filter
[n, Wn] = ellipord(Wp, Ws, Rp, Rs);
[b, a] = ellip(n, Rp, Rs, Wn, 'bandpass');

% Apply filter
filtered_audio = filter(b, a, audio);

% Display filter information
fprintf('Elliptic Bandpass Filter Design:\n');
fprintf('Filter order: %d\n', n);
fprintf('Passband: %.0f - %.0f Hz\n', Wp(1)*fs/2, Wp(2)*fs/2);
fprintf('Stopband: %.0f - %.0f Hz\n', Ws(1)*fs/2, Ws(2)*fs/2);
fprintf('Passband ripple: %.1f dB\n', Rp);
fprintf('Stopband attenuation: %.0f dB\n', Rs);
fprintf('Sampling frequency: %d Hz\n', fs);

% Visualize filter characteristics
figure('Name', 'Elliptic Bandpass Filter Analysis', 'Position', [100, 100, 1400, 900]);

% Filter frequency response
subplot(2,3,1);
[H, w] = freqz(b, a, 2048, fs);
plot(w, 20*log10(abs(H)), 'LineWidth', 2, 'Color', [0 0.5 1]);
hold on;
% Add passband edges
plot([Wp(1)*fs/2 Wp(1)*fs/2], [-60 5], 'r--', 'LineWidth', 1.5);
plot([Wp(2)*fs/2 Wp(2)*fs/2], [-60 5], 'r--', 'LineWidth', 1.5);
% Add stopband edges
plot([Ws(1)*fs/2 Ws(1)*fs/2], [-60 5], 'g:', 'LineWidth', 1.5);
plot([Ws(2)*fs/2 Ws(2)*fs/2], [-60 5], 'g:', 'LineWidth', 1.5);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Elliptic Bandpass Filter Response');
legend('Filter', 'Passband', '', 'Stopband', '', 'Location', 'best');
grid on;
xlim([0 fs/2]);
ylim([-60 5]);

% Detailed magnitude response
subplot(2,3,2);
[H, w] = freqz(b, a, 4096);  % Higher resolution
f_hz = w * fs / (2*pi);
plot(f_hz, 20*log10(abs(H)), 'LineWidth', 2, 'Color', [0.8 0.4 0]);
hold on;
plot([Wp(1)*fs/2 Wp(1)*fs/2], [-60 5], 'r--', 'LineWidth', 1.5);
plot([Wp(2)*fs/2 Wp(2)*fs/2], [-60 5], 'r--', 'LineWidth', 1.5);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title(sprintf('Detailed Magnitude Response (Order %d)', n));
grid on;
xlim([0 5000]);
ylim([-60 5]);

% Phase response
subplot(2,3,3);
plot(f_hz, unwrap(angle(H))*180/pi, 'LineWidth', 2, 'Color', [0 0.6 0]);
hold on;
plot([Wp(1)*fs/2 Wp(1)*fs/2], [min(unwrap(angle(H))*180/pi) max(unwrap(angle(H))*180/pi)], 'r--', 'LineWidth', 1.5);
plot([Wp(2)*fs/2 Wp(2)*fs/2], [min(unwrap(angle(H))*180/pi) max(unwrap(angle(H))*180/pi)], 'r--', 'LineWidth', 1.5);
hold off;
xlabel('Frequency (Hz)');
ylabel('Phase (degrees)');
title('Phase Response');
grid on;
xlim([0 5000]);

% Pole-zero plot
subplot(2,3,4);
zplane(b, a);
title(sprintf('Pole-Zero Plot (Order %d)', n));

% Time domain comparison (2s to 2.1s)
start_time = 2.0;
end_time = 2.1;
start_sample = max(1, round(start_time * fs) + 1);
end_sample = min(length(audio), round(end_time * fs));
time_segment = start_sample:end_sample;

subplot(2,3,5);
if end_sample <= length(audio)
    t = (0:length(audio)-1)/fs;
    t_segment = t(time_segment);
    
    plot(t_segment, audio(time_segment), 'b', 'LineWidth', 1.5);
    hold on;
    plot(t_segment, filtered_audio(time_segment), 'r', 'LineWidth', 1.5);
    hold off;
    xlabel('Time (s)');
    ylabel('Amplitude');
    title('Waveform Comparison (2.0s to 2.1s)');
    legend('Original', 'Bandpass Filtered', 'Location', 'best');
    grid on;
    xlim([start_time end_time]);
else
    text(0.5, 0.5, 'Audio too short for 2s-2.1s segment', ...
         'HorizontalAlignment', 'center', 'FontSize', 12);
    title('Audio Segment Not Available');
    xlabel('Time (s)');
    ylabel('Amplitude');
end

% Frequency spectrum comparison (using 2s to 2.1s segment)
N_fft = 4096;
f = (0:N_fft/2-1)*(fs/N_fft);

% Use the same time segment for frequency analysis
if end_sample <= length(audio) && end_sample <= length(filtered_audio)
    audio_seg = audio(time_segment);
    filtered_seg = filtered_audio(time_segment);
    
    % Pad or truncate to N_fft length
    if length(audio_seg) < N_fft
        audio_seg = [audio_seg; zeros(N_fft - length(audio_seg), 1)];
        filtered_seg = [filtered_seg; zeros(N_fft - length(filtered_seg), 1)];
    else
        audio_seg = audio_seg(1:N_fft);
        filtered_seg = filtered_seg(1:N_fft);
    end
    
    Y_orig = abs(fft(audio_seg, N_fft));
    Y_filt = abs(fft(filtered_seg, N_fft));
else
    Y_orig = abs(fft(audio, N_fft));
    Y_filt = abs(fft(filtered_audio, N_fft));
end

subplot(2,3,6);
plot(f, 20*log10(Y_orig(1:N_fft/2)), 'b', 'LineWidth', 1.5);
hold on;
plot(f, 20*log10(Y_filt(1:N_fft/2)), 'r', 'LineWidth', 1.5);
% Add passband edges
plot([Wp(1)*fs/2 Wp(1)*fs/2], [-60 60], 'k--', 'LineWidth', 1);
plot([Wp(2)*fs/2 Wp(2)*fs/2], [-60 60], 'k--', 'LineWidth', 1);
hold off;
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Spectrum Comparison (2.0s to 2.1s)');
legend('Original', 'Bandpass Filtered', 'Passband', '', 'Location', 'best');
grid on;
xlim([0 8000]);
ylim([-60 60]);

% Save filtered audio
output_dir = '../samples/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
audiowrite([output_dir 'elliptic_bandpass_output.wav'], filtered_audio, fs);

fprintf('\nElliptic Bandpass filter applied successfully!\n');
fprintf('Filtered audio saved as elliptic_bandpass_output.wav in samples folder\n');
