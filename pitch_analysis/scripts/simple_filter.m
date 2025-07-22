fs = 44100;
t = 0:1/fs:0.01;
x = sawtooth(2*pi*440*t); % Generate sawtooth wave
[b, a] = butter(4, 1000/(fs/2), 'low'); % 1 kHz LPF
y = filter(b, a, x);

subplot(2,1,1);
plot(t, x); title('Original Sawtooth Wave');
subplot(2,1,2);
plot(t, y); title('Filtered Waveform');

% Save figure with meaningful name
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, 'simple_filter_sawtooth_demo.png'));
fprintf('Figure saved as: simple_filter_sawtooth_demo.png\n');
