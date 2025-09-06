% Simple Filter Comparison Analysis
% Compares Butterworth, Chebyshev I, Chebyshev II, Elliptic, and Bessel filters
% Plots Magnitude, Phase, and Group Delay responses in one vertically stacked figure

% Import audio file
[file, path] = uigetfile({'*.wav'; '*.mp3'}, 'Select an audio file for filter comparison');
if isequal(file,0)
    disp('No file selected. Exiting script.');
    return;
end
audio_filepath = fullfile(path, file);
[audio, fs] = audioread(audio_filepath);
if size(audio, 2) > 1
    audio = mean(audio, 2);
end

% Filter parameters
fc = 1000;  % Cutoff frequency (Hz)
order = 6;  % Filter order
Wn = fc/(fs/2);  % Normalized frequency
Rp = 0.5;  % Passband ripple (dB)
Rs = 40;   % Stopband attenuation (dB)

% Design filters
[b_butter, a_butter] = butter(order, Wn, 'low');
[b_cheby1, a_cheby1] = cheby1(order, Rp, Wn, 'low');
[b_cheby2, a_cheby2] = cheby2(order, Rs, Wn, 'low');
[b_ellip, a_ellip] = ellip(order, Rp, Rs, Wn, 'low');
[b_bessel, a_bessel] = besself(order, 2*pi*fc);
[b_bessel, a_bessel] = bilinear(b_bessel, a_bessel, fs);

filters = {
    {b_butter, a_butter, 'Butterworth', 'b'};
    {b_cheby1, a_cheby1, 'Chebyshev I', 'r'};
    {b_cheby2, a_cheby2, 'Chebyshev II', 'g'};
    {b_ellip, a_ellip, 'Elliptic', 'm'};
    {b_bessel, a_bessel, 'Bessel', 'c'};
};

figure('Name', 'Simple Filter Comparison', 'Position', [100, 100, 900, 900]);
clf; % Clear figure to avoid overlay issues
w = linspace(10, 1.5*fc, 2048);

% Magnitude Response
subplot(3,1,1);
for i = 1:length(filters)
    [H, ~] = freqz(filters{i}{1}, filters{i}{2}, w, fs);
    plot(w, 20*log10(abs(H)), filters{i}{4}, 'LineWidth', 2);
    hold on;
end
xlabel('Frequency (Hz)'); ylabel('Magnitude (dB)');
title('Magnitude Response'); grid on;
legend(cellfun(@(x)x{3}, filters, 'UniformOutput', false), 'Location', 'best');
xlim([0 1.5*fc]); ylim([-100 10]);
hold off;

% Phase Response
subplot(3,1,2);
for i = 1:length(filters)
    [H, ~] = freqz(filters{i}{1}, filters{i}{2}, w, fs);
    plot(w, unwrap(angle(H))*180/pi, filters{i}{4}, 'LineWidth', 2);
    hold on;
end
xlabel('Frequency (Hz)'); ylabel('Phase (degrees)');
title('Phase Response'); grid on;
legend(cellfun(@(x)x{3}, filters, 'UniformOutput', false), 'Location', 'best');
xlim([0 1.5*fc]);
hold off;

% Group Delay
subplot(3,1,3);
for i = 1:length(filters)
    [gd, w_gd] = grpdelay(filters{i}{1}, filters{i}{2}, 512);
    f_gd = w_gd * fs / (2*pi);
    plot(f_gd, gd, filters{i}{4}, 'LineWidth', 2);
    hold on;
end
xlabel('Frequency (Hz)'); ylabel('Group Delay (samples)');
title('Group Delay'); grid on;
legend(cellfun(@(x)x{3}, filters, 'UniformOutput', false), 'Location', 'best');
xlim([0 1.5*fc]);
hold off;

% Apply filters and save audio (optional)
output_dir = '../samples/';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
for i = 1:length(filters)
    filtered_audio = filter(filters{i}{1}, filters{i}{2}, audio);
    filename = sprintf('%sfilter_comparison_%s.wav', output_dir, lower(strrep(filters{i}{3}, ' ', '_')));
    audiowrite(filename, filtered_audio/max(abs(filtered_audio)), fs);
end
