use inc::Module::Install;
name 'Pod-Translate';
all_from 'lib/Pod/Translate.pm';
license 'perl';
#install_script glob('script/*.pl');
githubmeta;
cpanfile;
auto_provides;
readme_from '', 'clean';
# https://github.com/bingos/module-install-githubmeta
makemaker_args(dist => { PREOP => "$^X ./tools/git-log.pl > ./Changes" });
WriteAll;
