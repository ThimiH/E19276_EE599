% resonator_complex_poles.m
% Resonator Design Using Complex Poles
% Models instrument resonances and creates resonant filters

% Parameters
fs = 44100;                    % Sample rate
f_res = [220, 440, 880, 1760]; % Resonant frequencies (A notes)
r_values = [0.95, 0.98, 0.99];  % Different pole radii for comparison
duration = 2;                  % Duration in seconds
N = duration * fs;             % Number of samples

% Create impulse and white noise inputs
impulse = [1; zeros(N-1, 1)];
noise = 0.1 * randn(N, 1);

figure('Name', 'Resonator Analysis Using Complex Poles');

% 1. Single resonator analysis (440 Hz)
f0 = 440;  % A4 note
r = 0.98;  % Pole radius
theta = 2*pi*f0/fs;  % Pole angle

% Filter coefficients for resonator
b = [0, 1, 0];  % Numerator (adds a zero at origin for better response)
a = [1, -2*r*cos(theta), r^2];  % Denominator with complex poles

% Impulse response
subplot(2,3,1);
y_impulse = filter(b, a, impulse);
t = (0:length(y_impulse)-1)/fs;
plot(t(1:1000), y_impulse(1:1000));
xlabel('Time (s)');
ylabel('Amplitude');
title(sprintf('Impulse Response (f=%.0f Hz, r=%.2f)', f0, r));
grid on;

% Frequency response
subplot(2,3,2);
[H, w] = freqz(b, a, 1024);
f_hz = w * fs / (2*pi);
plot(f_hz, 20*log10(abs(H)));
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Resonator Frequency Response');
grid on;
xlim([0 2000]);

% Pole-zero plot
subplot(2,3,3);
zplane(b, a);
title('Pole-Zero Plot');

% 2. Effect of pole radius on resonance
subplot(2,3,4);
for i = 1:length(r_values)
    r = r_values(i);
    a_temp = [1, -2*r*cos(theta), r^2];
    [H, w] = freqz(b, a_temp, 1024);
    f_hz = w * fs / (2*pi);
    plot(f_hz, 20*log10(abs(H)), 'LineWidth', 1.5);
    hold on;
end
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Effect of Pole Radius on Resonance');
legend(arrayfun(@(x) sprintf('r=%.2f', x), r_values, 'UniformOutput', false), ...
       'Location', 'best');
grid on;
xlim([300 600]);
hold off;

% 3. Multiple resonators (chord simulation)
subplot(2,3,5);
y_chord = zeros(N, 1);
for i = 1:length(f_res)
    theta_i = 2*pi*f_res(i)/fs;
    a_i = [1, -2*0.98*cos(theta_i), 0.98^2];
    y_temp = filter(b, a_i, impulse);
    y_chord = y_chord + y_temp;
end
plot(t(1:2000), y_chord(1:2000));
xlabel('Time (s)');
ylabel('Amplitude');
title('Multiple Resonators (A Major Chord)');
grid on;

% Spectrum of chord
subplot(2,3,6);
N_fft = 4096;
f = (0:N_fft/2-1)*(fs/N_fft);
Y_chord = abs(fft(y_chord, N_fft));
plot(f, 20*log10(Y_chord(1:N_fft/2)));
xlabel('Frequency (Hz)');
ylabel('Magnitude (dB)');
title('Spectrum of Resonated Chord');
grid on;
xlim([0 3000]);

% Mark resonant frequencies
hold on;
for i = 1:length(f_res)
    line([f_res(i) f_res(i)], ylim, 'Color', 'r', 'LineStyle', '--', 'LineWidth', 1);
end
hold off;

% Save resonated audio examples
audiowrite('../Samples/single_resonator_440Hz.wav', y_impulse/max(abs(y_impulse)), fs);
audiowrite('../Samples/chord_resonators.wav', y_chord/max(abs(y_chord)), fs);

% Apply resonator to actual audio
try
    [audio, fs_audio] = audioread('../Samples/original_audio.wav');
    if fs_audio ~= fs
        audio = resample(audio, fs, fs_audio);
    end
catch
    [audio, fs_audio] = audioread('../Samples/Gajaman-Nona-Yohani-Ft-Tehan-Perera-www.song.lk.mp3');
    if size(audio, 2) > 1
        audio = mean(audio, 2);
    end
    if fs_audio ~= fs
        audio = resample(audio, fs, fs_audio);
    end
end

% Apply 440 Hz resonator to audio
audio_short = audio(1:min(length(audio), N));
resonated_audio = filter(b, a, audio_short);
audiowrite('../Samples/resonated_audio_440Hz.wav', resonated_audio/max(abs(resonated_audio)), fs);

fprintf('Resonator analysis completed!\n');
fprintf('Resonant frequencies analyzed: ');
fprintf('%.0f ', f_res);
fprintf('Hz\n');
fprintf('Audio files saved:\n');
fprintf('- single_resonator_440Hz.wav\n');
fprintf('- chord_resonators.wav\n');
fprintf('- resonated_audio_440Hz.wav\n');
