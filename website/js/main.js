// === Dynamic year in footer ===
document.getElementById('year').textContent = new Date().getFullYear();

// === Mobile nav toggle ===
const toggle = document.querySelector('.nav-toggle');
const navLinks = document.querySelector('.nav-links');

toggle.addEventListener('click', () => {
  const open = navLinks.classList.toggle('open');
  toggle.setAttribute('aria-expanded', open);
});

// Close mobile nav when a link is clicked
navLinks.querySelectorAll('a').forEach(link => {
  link.addEventListener('click', () => {
    navLinks.classList.remove('open');
    toggle.setAttribute('aria-expanded', false);
  });
});

// === Scroll reveal ===
const revealEls = document.querySelectorAll('.reveal');

const observer = new IntersectionObserver(
  (entries) => {
    entries.forEach((entry, i) => {
      if (entry.isIntersecting) {
        // Stagger sibling reveals slightly
        const siblings = entry.target.parentElement.querySelectorAll('.reveal');
        let delay = 0;
        siblings.forEach((el, idx) => {
          if (el === entry.target) delay = idx * 80;
        });
        setTimeout(() => {
          entry.target.classList.add('visible');
        }, delay);
        observer.unobserve(entry.target);
      }
    });
  },
  { threshold: 0.12 }
);

revealEls.forEach(el => observer.observe(el));

// === Highlight active nav link on scroll ===
const sections = document.querySelectorAll('section[id]');
const navAnchors = document.querySelectorAll('.nav-links a[href^="#"]');

const sectionObserver = new IntersectionObserver(
  (entries) => {
    entries.forEach(entry => {
      if (entry.isIntersecting) {
        navAnchors.forEach(a => {
          a.style.color = '';
          if (a.getAttribute('href') === `#${entry.target.id}`) {
            a.style.color = 'var(--color-text)';
          }
        });
      }
    });
  },
  { rootMargin: '-40% 0px -55% 0px' }
);

sections.forEach(s => sectionObserver.observe(s));

// === Load projects from the API ===
const PROJECTS_API_URL = 'https://api.jasontaylor.info/projects';
const projectsGrid = document.getElementById('projects-grid');

function escapeHtml(str) {
  const div = document.createElement('div');
  div.textContent = str ?? '';
  return div.innerHTML;
}

function projectCardHtml(project) {
  const link = project.github_url
    ? `<a href="${escapeHtml(project.github_url)}" class="project-link" target="_blank" rel="noopener" aria-label="View on GitHub">
        <svg xmlns="http://www.w3.org/2000/svg" width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"/><polyline points="15 3 21 3 21 9"/><line x1="10" y1="14" x2="21" y2="3"/></svg>
      </a>`
    : '';

  return `
    <article class="project-card reveal">
      <div class="project-card-header">
        <h3 class="project-title">${escapeHtml(project.title)}</h3>
        ${link}
      </div>
      <p class="project-desc">${escapeHtml(project.description)}</p>
    </article>
  `;
}

fetch(PROJECTS_API_URL)
  .then(res => {
    if (!res.ok) throw new Error(`Request failed: ${res.status}`);
    return res.json();
  })
  .then(projects => {
    projectsGrid.innerHTML = projects.map(projectCardHtml).join('');
    projectsGrid.querySelectorAll('.reveal').forEach(el => observer.observe(el));
  })
  .catch(err => {
    projectsGrid.innerHTML = '<p class="projects-status">Unable to load projects right now.</p>';
    console.error('Failed to load projects:', err);
  });
