const gulp = require('gulp');
const sass = require('gulp-sass')(require('sass'));

// Compile SCSS to CSS
function compileSCSS() {
  return gulp
    .src('scss/global.scss')        // entry point
    .pipe(sass().on('error', sass.logError))
    .pipe(gulp.dest('css'));        // output path
}

// Watch for changes
function watchFiles() {
  gulp.watch('scss/**/*.scss', compileSCSS);
}

exports.default = gulp.series(compileSCSS, watchFiles);