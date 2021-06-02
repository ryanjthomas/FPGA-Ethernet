#ifndef UTILS_HPP
#define UTILS_HPP
void print_progress(float progress, int barwidth=70) {
	std::cout << "[";
	int pos = barwidth * progress;
	for (int i = 0; i < barwidth; ++i) {
		if (i < pos) std::cout << "=";
		else if (i == pos) std::cout << ">";
		else std::cout << " ";
	}
	std::cout << "] " << int(progress * 100.0) << " %\r";
	std::cout.flush();
}
#endif UTILS_HPP
