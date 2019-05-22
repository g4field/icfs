Gem::Specification.new do |gs|
  gs.version = '0.1.1'

  gs.name = 'icfs'
  gs.license = 'GPL-3.0'
  gs.authors = [ 'Graham A. Field' ]
  gs.email = 'gfield@retr.org'
  gs.homepage = 'https://github.com/g4field/icfs'
  gs.summary = 'Investigative Case File System'
  gs.description = '
    ICFS is a case management and filing system, developed for investigative
    cases, but generally applicable to many types of work. It provides a
    structured way to store and retrieve information, a case-focused access
    control scheme which can integrate into existing identity and access
    management systems, a flexible way to manage and track work assignments,
    and a way to gather statistics which is flexible and can be audited.'

  gs.files = [
      'LICENSE.txt',
    ] +
    Dir['lib/**/*'] +
    Dir['bin/*'] +
    Dir['data/*']
end
