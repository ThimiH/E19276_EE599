f = 262;                % Frequency in Hz (C note)
fs = 44100;             % Sampling frequency
t = 0:1/fs:0.01;        % Time vector
y = sin(2*pi*f*t);
plot(t, y);
title('Sine Wave of 262 Hz (C note)');
xlabel('Time (s)');
ylabel('Amplitude');

% Save figure with meaningful name
output_dir = '../outputs';
if ~exist(output_dir, 'dir')
    mkdir(output_dir);
end
saveas(gcf, fullfile(output_dir, 'sine_wave_262Hz_demo.png'));
fprintf('Figure saved as: sine_wave_262Hz_demo.png\n');
